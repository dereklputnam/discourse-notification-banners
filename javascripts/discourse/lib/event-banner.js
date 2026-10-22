const MINUTE = 60 * 1000;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;

const FALLBACK_LIVE_MESSAGE = "Our event is starting now!";

function plural(count, unit) {
  return `${count} ${unit}${count === 1 ? "" : "s"}`;
}

function parseTime(value) {
  const time = value ? Date.parse(value) : NaN;
  return Number.isNaN(time) ? null : time;
}

// Parses a topic id from a Discourse topic URL such as /t/slug/123 or /t/123/4.
export function topicIdFromUrl(url) {
  const match = String(url ?? "").match(/\/t\/(?:[^/?#]+\/)?(\d+)/);
  return match ? Number(match[1]) : null;
}

// "5 hours", "1 hour 30 minutes", "45 minutes", "less than a minute".
export function formatCountdown(ms) {
  if (ms < MINUTE) {
    return "less than a minute";
  }
  if (ms >= DAY) {
    const days = Math.floor(ms / DAY);
    const hours = Math.floor((ms % DAY) / HOUR);
    return hours ? `${plural(days, "day")} ${plural(hours, "hour")}` : plural(days, "day");
  }
  const hours = Math.floor(ms / HOUR);
  const minutes = Math.floor((ms % HOUR) / MINUTE);
  if (hours === 0) {
    return plural(minutes, "minute");
  }
  if (hours < 3 && minutes) {
    return `${plural(hours, "hour")} ${plural(minutes, "minute")}`;
  }
  return plural(hours, "hour");
}

function startOfDay(time) {
  const date = new Date(time);
  return new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
}

// Start time in the viewer's timezone, styled like Discourse local dates:
// "today 2:00 PM", "tomorrow 2:00 PM", "Thursday at 2:00 PM" (within a week),
// then "October 23, 2026 2:00 PM".
export function formatLocalTime(time, now, locale) {
  const clock = new Intl.DateTimeFormat(locale, {
    hour: "numeric",
    minute: "2-digit",
  }).format(time);
  const days = Math.round((startOfDay(time) - startOfDay(now)) / DAY);
  if (days === 0) {
    return `today ${clock}`;
  }
  if (days === 1) {
    return `tomorrow ${clock}`;
  }
  if (days > 1 && days < 7) {
    const weekday = new Intl.DateTimeFormat(locale, { weekday: "long" }).format(
      time
    );
    return `${weekday} at ${clock}`;
  }
  const date = new Intl.DateTimeFormat(locale, {
    month: "long",
    day: "numeric",
    year: "numeric",
  }).format(time);
  return `${date} ${clock}`;
}

// Returns null for a regular banner, otherwise { phase, start, end, ms }.
// phase is "before", "soon" (only with a soon_message), "live" or "ended". Manual fields override the topic event.
// A banner that references a topic whose event can't be resolved returns
// { phase: "ended" } so it stays hidden instead of showing a wrong message.
export function eventState(banner, topicEvent, now, liveMinutes, soonMinutes = 5) {
  const hasEventConfig =
    banner.event_start || banner.event_end || banner.event_topic;
  if (!hasEventConfig) {
    return null;
  }

  const start = parseTime(banner.event_start) ?? parseTime(topicEvent?.starts_at);
  if (start === null) {
    return { phase: "ended" };
  }

  const end =
    parseTime(banner.event_end) ??
    parseTime(topicEvent?.ends_at) ??
    start + liveMinutes * MINUTE;

  if (now < start) {
    const ms = start - now;
    const soon = banner.soon_message && ms <= soonMinutes * MINUTE;
    return { phase: soon ? "soon" : "before", start, end, now, ms };
  }
  return { phase: now < end ? "live" : "ended", start, end, ms: 0 };
}

export function eventMessage(banner, state) {
  let message;
  if (state.phase === "live") {
    message = banner.live_message || FALLBACK_LIVE_MESSAGE;
  } else if (state.phase === "soon") {
    message = banner.soon_message;
  } else {
    message = banner.message;
  }

  // More than an hour out, show the local start time; then count down ("in 45 minutes").
  const countdown =
    state.ms > HOUR
      ? formatLocalTime(state.start, state.now)
      : `in ${formatCountdown(state.ms)}`;
  return message.replaceAll("{countdown}", countdown);
}
