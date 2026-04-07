import { apiInitializer } from "discourse/lib/api";
import loadScript from "discourse/lib/load-script";
import NotificationBanners from "../components/notification-banners";

function loadSplideCSS() {
  if (document.getElementById("splide-css")) {
    return;
  }

  const link = document.createElement("link");
  Object.assign(link, {
    rel: "stylesheet",
    type: "text/css",
    id: "splide-css",
    href: settings.theme_uploads.splide_css,
  });
  document.head.appendChild(link);
}

// Utility function to transform outlet name for settings lookup
function normalizeName(outlet) {
  return outlet.replaceAll("-", "_");
}

function slugify(str) {
  str = str
    .trim() // trim leading/trailing white space
    .replace(/[^a-zA-Z0-9 -]/g, "") // remove any non-alphanumeric characters
    .replace(/\s+/g, "-") // replace spaces with hyphens
    .replace(/-+/g, "-") // remove consecutive hyphens
    .padEnd(6, "0");
  return str;
}

export default apiInitializer((api) => {
  loadSplideCSS();

  const bannerConfigVersion = settings.banner_config_version;

  const banners = [...settings.banners].reduce((acc, banner) => {
    const outlet = banner.plugin_outlet;
    const type = banner.carousel ? "carousel" : "solo";

    // Create new object instead of mutating
    const processedBanner = {
      ...banner,
      id: `notification-banner--${slugify(banner.id)}--${bannerConfigVersion}`,
    };

    // Initialize outlet if it doesn't exist
    if (!acc[outlet]) {
      acc[outlet] = {
        carousel: [],
        solo: [],
      };
    }

    // Add banner to appropriate array
    acc[outlet][type].push(processedBanner);

    return acc;
  }, {});

  Object.keys(banners).forEach((outlet) => {
    const carouselBanners = banners[outlet].carousel;
    const soloBanners = banners[outlet].solo;
    const splideOptions = settings[`splide_options__${normalizeName(outlet)}`];

    api.renderInOutlet(
      outlet,
      <template>
        <NotificationBanners
          @outlet={{outlet}}
          @carouselBanners={{carouselBanners}}
          @soloBanners={{soloBanners}}
          @splideOptions={{splideOptions}}
        />
      </template>
    );
  });

  loadScript(settings.theme_uploads.splide_js).then(() => {
    const el = document.querySelectorAll(
      ".splide.notification-banners--above-site-header, .splide.notification-banners--below-site-header, .splide.notification-banners--above-main-container, .splide.notification-banners--top-notices"
    );
    el.forEach((carousel) => {
      // eslint-disable-next-line no-undef
      new Splide(carousel).mount();
    });
  });
});
