/* js/main.js */
document.addEventListener("DOMContentLoaded", () => {
  const year = document.getElementById("current-year");

  if (year) {
    year.textContent = new Date().getFullYear().toString();
  }
});
