import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { service } from "@ember/service";
import NotificationBanner from "./notification-banner";

const TL_GROUPS = [10, 11, 12, 13, 14];

export default class NotificationBanners extends Component {
  @service currentUser;
  @service router;
  @service site;

  #filterBanners(banner) {
    const currentRoute = this.router.currentRoute;
    const now = Date.now();

    return (
      !this.#adminRoute(currentRoute) &&
      this.#matchedCategory(banner, currentRoute) &&
      this.#matchedAudience(banner) &&
      this.#withinDateRange(banner, now)
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
    // If no groups are specified, allow the banner
    if (banner.enabled_groups?.length === 1 && banner.enabled_groups[0] === 0) {
      return true;
    }

    // If groups are specified, check if user has any of them
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
                <NotificationBanner @banner={{banner}} />
              </li>
            {{/each}}
          </ul>
        </div>
      </section>
    {{/if}}

    {{#if this.enabledSoloBanners}}
      <section class="notification-banners--{{@outlet}}">
        {{#each this.enabledSoloBanners as |banner|}}
          <NotificationBanner @banner={{banner}} />
        {{/each}}
      </section>
    {{/if}}
  </template>
}
