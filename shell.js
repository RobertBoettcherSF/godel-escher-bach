import {applyLanguage, getLang, setLang} from "./i18n.js?v=1";
import {bindSoundButton, play} from "./sounds.js?v=1";
import {bindDebug} from "./debug.js?v=1";

applyLanguage(getLang());
bindSoundButton();
bindDebug();

document.querySelectorAll("[data-language]").forEach((button) => {
  button.addEventListener("click", () => {
    setLang(button.dataset.language);
    play("language");
  });
});

window.GEB = window.GEB || {};
window.GEB.state = Object.assign(
  {wasm: "", string: "—", history: "—", error: "—"},
  window.GEB.state
);
