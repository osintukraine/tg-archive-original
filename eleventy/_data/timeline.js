const months = require('./months');
const out = {};
for(const m of months){
  const year = m.date.slice(0,4);
  if(!out[year]) out[year] = [];
  out[year].push(m);
}
module.exports = out;
