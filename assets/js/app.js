// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import "../css/app.scss";

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import deps with the dep name or local files with a relative path, for example:
//
//     import {Socket} from "phoenix"
//     import socket from "./socket"
//
import "phoenix_html";
import 'bootstrap';
import { Socket } from "phoenix";
import NProgress from "nprogress";
import { LiveSocket } from "phoenix_live_view";
import $ from 'jquery';

import ProgressBar from "progressbar.js"

let Hooks = {};

Hooks.ShareLink = {
  mounted() {
    let button = $(this.el);
    this.el.addEventListener("click", e => {
      const el = document.createElement('textarea');
      const newText = button.data("text")
      el.value = button.data('link');
      button.text(newText);
      el.setAttribute('readonly', '');
      el.style.position = 'absolute';
      el.style.left = '-9999px';
      document.body.appendChild(el);
      el.focus();
      el.select();
      document.execCommand('copy');
      document.body.removeChild(el);
    });

  }
}

Hooks.TypeFilter = {
  mounted() {
    let type = this.el.dataset.type;

    this.el.addEventListener("click", (e) => {
      let parent = $(this.el).closest(".modal-body")
      let time = parent.find(".time-filter.active").data("time")
      parent.find(".type-filter").removeClass("active");
      $(this.el).addClass("active");

      parent.find(".type-list").addClass("d-none");
      parent.find(`.${type}-${time}`).removeClass("d-none")
    })
  }
}

Hooks.TimeFilter = {
  mounted() {
    let time = this.el.dataset.time;

    this.el.addEventListener("click", (e) => {
      let parent = $(this.el).closest(".modal-body")
      let type = parent.find(".type-filter.active").data("type")

      parent.find(".time-filter").removeClass("active");
      $(this.el).addClass("active");

      parent.find(".type-list").addClass("d-none");
      parent.find(`.${type}-${time}`).removeClass("d-none")
    })
  }
}

Hooks.ProgressCircle = {
  mounted() {
    setupProgressCircles(false)
  },
  updated() {
    setupProgressCircles(true)
  }
}

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");

let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
});

// Show progress bar on live navigation and form submits
window.addEventListener("phx:page-loading-start", () => NProgress.start());
window.addEventListener("phx:page-loading-stop", info => {
  NProgress.done();
});

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)
window.liveSocket = liveSocket;



window.$ = $;

function setupProgressCircles(updating) {
  let PurposeStyle = (function () {

    // Variables

    let style = getComputedStyle(document.body);
    let colors = {
      gray: {
        100: '#f6f9fc',
        200: '#e9ecef',
        300: '#dee2e6',
        400: '#ced4da',
        500: '#adb5bd',
        600: '#8898aa',
        700: '#525f7f',
        800: '#32325d',
        900: '#212529'
      },
      theme: {
        'primary': style.getPropertyValue('--primary') ? style.getPropertyValue('--primary').replace(' ', '') : '#6e00ff',
        'info': style.getPropertyValue('--info') ? style.getPropertyValue('--info').replace(' ', '') : '#00B8D9',
        'success': style.getPropertyValue('--success') ? style.getPropertyValue('--success').replace(' ', '') : '#36B37E',
        'danger': style.getPropertyValue('--danger') ? style.getPropertyValue('--danger').replace(' ', '') : '#FF5630',
        'warning': style.getPropertyValue('--warning') ? style.getPropertyValue('--warning').replace(' ', '') : '#FFAB00',
        'dark': style.getPropertyValue('--dark') ? style.getPropertyValue('--dark').replace(' ', '') : '#212529'
      },
      transparent: 'transparent',
    },
      fonts = {
        base: 'Nunito'
      }

    // Return

    return {
      colors: colors,
      fonts: fonts
    };

  })();
  let ProgressCircle = (function () {

    // Variables

    let $progress = $('.progress-circle');

    // Methods

    function init($this) {

      let value = $this.data().progress,
        text = $this.data().text ? $this.data().text : '',
        textClass = $this.data().textclass ? $this.data().textclass : 'progressbar-text',
        color = $this.data().color ? $this.data().color : 'primary';

      let options = {
        color: PurposeStyle.colors.theme[color],
        strokeWidth: 7,
        trailWidth: 2,
        text: {
          value: text,
          className: textClass
        },
        svgStyle: {
          display: 'block',
        },
        duration: 1500,
        easing: 'easeInOut',
        fill: 'rgba(54, 179, 126, 0.3)',
      };

      let progress = new ProgressBar.Circle($this[0], options);

      if (updating) {
        progress.set(value / 100);
      } else {
        progress.animate(value / 100);
      }

    }

    // Events

    if ($progress.length) {
      $progress.each(function () {
        init($(this));
      });
    }

  })();
}