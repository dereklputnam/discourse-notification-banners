import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { eventState, topicIdFromUrl } from "../lib/event-banner";
import NotificationBanner from "./notification-banner";

const TL_GROUPS = [10, 11, 12, 13, 14];
const TICK_MS = 30 * 1000;

// Topic events are shared between outlets so each topic is fetched once.
const topicEventRequests = new Map();

function fetchTopicEvent(topicUrl) {
  const id = topicIdFromUrl(topicUrl);
  if (!id) {
    return Promise.resolve(null);
  }
  if (!topicEventRequests.has(id)) {
    topicEventRequests.set(
      id,
      ajax(`/t/${id}.json`)
        .then((topic) => topic.post_stream?.posts?.[0]?.event ?? null)
        .catch(() => null)
    );
  }
  return topicEventRequests.get(id);
}

export default class NotificationBanners extends Component {
  @service currentUser;
  @service router;
  @service site;

  @tracked now = Date.now();
  @tracked topicEvents = {};

  constructor() {
    super(...arguments);
    this.timer = setInterval(() => (this.now = Date.now()), TICK_MS);
    this.#loadTopicEvents();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    clearInterval(this.timer);
  }

  async #loadTopicEvents() {
    const banners = [
      ...(this.args.carouselBanners ?? []),
      ...(this.args.soloBanners ?? []),
    ].filter((banner) => banner.event_topic);

    await Promise.all(
      banners.map(async (banner) => {
        const event = await fetchTopicEvent(banner.event_topic);
        if (event && !this.isDestroying && !this.isDestroyed) {
          this.topicEvents = { ...this.topicEvents, [banner.event_topic]: event };
        }
      })
    );
  }

  #filterBanners(banner) {
    const currentRoute = this.router.currentRoute;
    const now = Date.now();

    return (
      !this.#adminRoute(currentRoute) &&
      this.#matchedCategory(banner, currentRoute) &&
      this.#matchedAudience(banner) &&
      this.#withinDateRange(banner, now) &&
      this.#eventNotEnded(banner)
    );
  }

  #adminRoute(currentRoute) {
    return currentRoute.name?.startsWith("admin");
  }

  #matchedCategory(banner, currentRoute) {
    if (
      !("selected_categories" in banner) ||
      banner.selected_categories?.length === 0
    ) {
      return true;
    }

    if (currentRoute.name !== "discovery.category") {
      return false;
    }

    const categoryId = currentRoute.attributes?.category?.id;

    if (banner.selected_categories?.includes(categoryId)) {
      return true;
    }

    if (banner.include_subcategories) {
      const parentId = this.site.categories.find(
        (c) => c.id === categoryId
      )?.parent_category_id;
      return banner.selected_categories?.includes(parentId);
    }

    return false;
  }

  #matchedAudience(banner) {
    // Group membership is resolved server-side (resolve_group_membership), so
    // we avoid the deprecated currentUser.groups. Trust level groups match that
    // level and above, as in core.
    if (typeof banner.user_in_enabled_groups === "boolean") {
      return banner.user_in_enabled_groups;
    }

    // Fallback for Discourse versions without resolve_group_membership.
    if (banner.enabled_groups?.length === 1 && banner.enabled_groups[0] === 0) {
      return true;
    }

    const userGroupsSet = this.currentUserGroupsSet;
    return banner.enabled_groups
      .filter((group) => group !== 0)
      .some((group) => userGroupsSet.has(group));
  }

  #withinDateRange(banner, now) {
    const startDate = banner.date_after ? Date.parse(banner.date_after) : null;
    const endDate = banner.date_before ? Date.parse(banner.date_before) : null;

    if (startDate && now < startDate) {
      return false;
    }
    if (endDate && now > endDate) {
      return false;
    }

    return true;
  }

  #eventNotEnded(banner) {
    const state = eventState(
      banner,
      this.topicEvents[banner.event_topic],
      this.now,
      settings.event_live_duration_minutes,
      settings.event_soon_minutes
    );
    return state?.phase !== "ended";
  }

  get #filteredCarousel() {
    return (this.args.carouselBanners ?? []).filter(
      this.#filterBanners.bind(this)
    );
  }

  get #filteredSolo() {
    return (this.args.soloBanners ?? []).filter(
      this.#filterBanners.bind(this)
    );
  }

  get enabledCarouselBanners() {
    return this.#filteredCarousel.length >= 2 ? this.#filteredCarousel : [];
  }

  get enabledSoloBanners() {
    if (this.#filteredCarousel.length < 2) {
      return [...this.#filteredSolo, ...this.#filteredCarousel];
    }
    return this.#filteredSolo;
  }

  @cached
  get currentUserGroups() {
    if (!this.currentUser) {
      return [0];
    }

    const allGroups = this.currentUser.groups.map((group) => group.id);
    const tlGroups = allGroups.filter((g) => TL_GROUPS.includes(g));
    const highestTl = tlGroups.length > 0 ? [Math.max(...tlGroups)] : [];
    const nonTlGroups = allGroups.filter((group) => !tlGroups.includes(group));

    return [...highestTl, ...nonTlGroups];
  }

  @cached
  get currentUserGroupsSet() {
    return new Set(this.currentUserGroups);
  }

  <template>
    {{#if this.enabledCarouselBanners}}
      <section
        class="splide notification-banners--{{@outlet}}"
        aria-label="Notification banners"
        aria-roledescription="carousel"
        role="group"
        data-splide={{@splideOptions}}
      >
        <div class="splide__track">
          <ul class="splide__list">
            {{#each this.enabledCarouselBanners as |banner|}}
              <li class="splide__slide">
                <NotificationBanner
                  @banner={{banner}}
                  @now={{this.now}}
                  @topicEvents={{this.topicEvents}}
                />
              </li>
            {{/each}}
          </ul>
        </div>
      </section>
    {{/if}}

    {{#if this.enabledSoloBanners}}
      <section class="notification-banners--{{@outlet}}">
        {{#each this.enabledSoloBanners as |banner|}}
          <NotificationBanner
                  @banner={{banner}}
                  @now={{this.now}}
                  @topicEvents={{this.topicEvents}}
                />
        {{/each}}
      </section>
    {{/if}}
  </template>
}
