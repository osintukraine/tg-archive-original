const dayCounter = require("./_includes/components/day-counter-template");
const dayline = require("./_includes/components/dayline-template");
const timelineIdx = require("./_includes/components/timeline-index-template");
const pagination = require("./_includes/components/pagination-template");

module.exports = function(eleventyConfig) {
  eleventyConfig.addShortcode("daycounter", dayCounter);
  eleventyConfig.addShortcode("dayline", dayline);
  eleventyConfig.addShortcode("timelineindex", timelineIdx);
  eleventyConfig.addShortcode("pagination", pagination);
  return {
    dir: {
      input: '.',
      includes: '_includes',
      data: '_data',
      output: '../_site'
    },
    templateFormats: ['njk', '11ty.js'],
    htmlTemplateEngine: 'njk',
    dataTemplateEngine: 'njk',
    markdownTemplateEngine: 'njk',
    incremental: true
  };
};
