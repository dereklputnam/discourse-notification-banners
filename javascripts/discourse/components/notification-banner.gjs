import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import CookText from "discourse/components/cook-text";
import DButton from "discourse/components/d-button";
import dIcon from "discourse-common/helpers/d-icon";
import { eventMessage, eventState } from "../lib/event-banner";

export default class NotificationBanner extends Component {
  @tracked dismissRevision = 0;

  get eventState() {
    return eventState(
      this.args.banner,
      this.args.topicEvents?.[this.args.banner.event_topic],
      this.args.now ?? Date.now(),
      settings.event_live_duration_minutes,
      settings.event_soon_minutes
    );
  }

  get message() {
    const state = this.eventState;
    return state ? eventMessage(this.args.banner, state) : this.args.banner.message;
  }

  get title() {
    const live = this.eventState?.phase === "live";
    return (live && this.args.banner.live_title) || this.args.banner.title;
  }

  // The live stage of an event banner is dismissed separately from the countdown.
  get dismissKey() {
    const phase = this.eventState?.phase;
    return phase === "live" || phase === "soon"
      ? `${this.args.banner.id}--${phase}`
      : this.args.banner.id;
  }

  get dismissed() {
    // eslint-disable-next-line no-unused-expressions
    this.dismissRevision;
    return this.args.banner.dismissible
      ? !!localStorage.getItem(this.dismissKey)
      : false;
  }

  @action
  dismiss() {
    if (!this.args.banner.dismissible) {
      return;
    }
    localStorage.setItem(this.dismissKey, true);
    this.dismissRevision++;
  }

  get showBanner() {
    return !this.dismissed;
  }

  <template>
    {{#if this.showBanner}}
      <div
        id={{@banner.id}}
        class="notification-banner"
      >
        <div class="notification-banner__wrapper wrap">
          {{#if @banner.dismissible}}
            <div class="notification-banner__close">
              <DButton
                @icon="xmark"
                @action={{this.dismiss}}
                @title="banner.close"
                class="btn-transparent close"
              />
            </div>
          {{/if}}
          <div class="notification-banner__content">
            {{#if this.title}}
              <h2 class="notification-banner__header">
                {{#if @banner.icon}}
                  {{dIcon @banner.icon}}
                {{/if}}
                {{this.title}}
              </h2>
            {{/if}}
            <CookText @rawText={{this.message}} />
          </div>
        </div>
      </div>
    {{/if}}
  </template>
}
