export default function migrate(settings) {
  const toISOString = (value) => {
    if (!value) {
      return value;
    }
    const timestamp = Date.parse(value);
    if (isNaN(timestamp)) {
      return value;
    }
    return new Date(timestamp).toISOString();
  };

  if (settings.has("banners")) {
    const banners = settings.get("banners");
    const updatedBanners = banners.map((banner) => {
      const updated = { ...banner };
      if (updated.date_after) {
        updated.date_after = toISOString(updated.date_after);
      }
      if (updated.date_before) {
        updated.date_before = toISOString(updated.date_before);
      }
      return updated;
    });
    settings.set("banners", updatedBanners);
  }

  return settings;
}
