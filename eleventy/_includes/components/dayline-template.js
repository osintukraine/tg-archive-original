module.exports = function({dayline, month}) {
  function makeFilename(m, page) {
    return `${m.slug}${page > 1 ? '_' + page : ''}.html`;
  }
  return `<ul class="index">\n` +
    dayline.map(d => `  <li class="day-${d.slug}"><a href="${makeFilename(month, d.page)}#${d.slug}">${d.label} <span class="count">(${d.count})</span></a></li>`).join("\n") +
  `\n</ul>`;
};
