module.exports = function({current, total, month}) {
  if(total <= 1) return '';
  let out = '<ul class="pagination">';
  for(let p=1;p<=total;p++) {
    const cls = current === p ? 'active' : '';
    out += `\n  <li class="${cls}"><a href="${month.slug}${p>1?'_'+p:''}.html">${p}</a></li>`;
  }
  out += '\n</ul>';
  return out;
};
