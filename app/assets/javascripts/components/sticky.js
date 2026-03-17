import { Component } from "nhsuk-frontend";

/**
 * Sticky component
 */
export class Sticky extends Component {
  /**
   * @param {Element | null} $root - HTML element to use for component
   */
  constructor($root) {
    super($root);

    this.stickyElement = $root;
    this.stickyElementStyle = null;
    this.stickyElementTop = 0;

    this.determineStickyState = this.determineStickyState.bind(this);
    this.throttledStickyState = this.throttle(this.determineStickyState, 100);

    this.stickyElementStyle = window.getComputedStyle($root);
    this.stickyElementTop = parseInt(this.stickyElementStyle.top, 10);

    window.addEventListener("scroll", this.throttledStickyState);

    const nav = $root.querySelector(".app-secondary-navigation");
    if (nav) {
      document.documentElement.style.scrollPaddingTop = `${nav.offsetHeight}px`;
    }

    this.determineStickyState();
  }

  /**
   * Name for the component used when initialising using data-module attributes
   */
  static moduleName = "app-sticky";

  /**
   * Determine element’s sticky state
   */
  determineStickyState() {
    const currentTop = this.stickyElement.getBoundingClientRect().top;

    this.stickyElement.dataset.stuck = String(
      currentTop <= this.stickyElementTop,
    );
  }

  /**
   * Throttle
   *
   * @param {Function} callback - Function to throttle
   * @param {number} limit - Minimum time interval (in milliseconds)
   * @returns {Function} Throttled function
   */
  throttle(callback, limit) {
    let inThrottle;
    return function () {
      const args = arguments;
      const context = this;
      if (!inThrottle) {
        callback.apply(context, args);
        inThrottle = true;
        setTimeout(() => (inThrottle = false), limit);
      }
    };
  }
}
