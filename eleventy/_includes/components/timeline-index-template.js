module.exports = function({timeline, month}) {
  let out = '<ul class="timeline index">';
  Object.keys(timeline).sort().reverse().forEach(year => {
    const months = timeline[year];
    out += `\n<li><h3 class="year"><a href="${months[0].slug}.html">${year}</a></h3>`;
    out += '\n<ul class="months">';
    months.slice().reverse().forEach(m => {
      const sel = m.slug === month.slug ? ' class="selected"' : '';
      out += `\n  <li${sel}><a href="${m.slug}.html">${m.label} <span class="count">(${m.count})</span></a></li>`;
    });
    out += '\n</ul>\n</li>';
  });
  out += '\n</ul>';
  return out;
};
