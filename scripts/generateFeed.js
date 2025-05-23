const fs = require('fs');
const path = require('path');
const { Feed } = require('feed');

const meta = JSON.parse(fs.readFileSync(path.join(__dirname, '../fixtures/rss_metadata.json'), 'utf8'));
const messages = JSON.parse(fs.readFileSync(path.join(__dirname, '../fixtures/latest_messages.json'), 'utf8'));

const feed = new Feed({
  id: meta.site_url,
  title: meta.site_name.replace('{group}', meta.group),
  description: meta.site_description,
  generator: `tg-archive ${meta.version}`,
  link: meta.site_url
});

messages.forEach(msg => {
  const url = `${meta.site_url}/${msg.page}#${msg.id}`;
  const item = {
    id: url,
    title: `@${msg.user.username} on ${msg.date} (#${msg.id})`,
    link: url,
    date: new Date(msg.date),
    description: msg.content || ''
  };
  if (msg.media) {
    item.enclosure = {
      url: `${meta.site_url}/${meta.media_dir}/${msg.media.url}`,
      type: msg.media.mime,
      length: msg.media.length
    };
  }
  feed.addItem(item);
});

fs.writeFileSync(path.join(__dirname, '../index.xml'), feed.rss2());
fs.writeFileSync(path.join(__dirname, '../index.atom'), feed.atom1());

