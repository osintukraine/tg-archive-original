module.exports = function({dateSlug, label, count}) {
  return `<li class="day" id="${dateSlug}">
    <span class="title">${label} <span class="count">(${count} messages)</span></span>
  </li>`;
};
