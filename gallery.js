import "./shell.js?v=1";
import {play} from "./sounds.js?v=1";

document.querySelectorAll("a.tile").forEach((link) => {
  link.addEventListener("click", () => {
    play(link.classList.contains("locked") ? "locked" : "open");
  });
});
