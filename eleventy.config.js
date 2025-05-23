module.exports = function(eleventyConfig) {
  return {
    dir: {
      input: "templates",
      data: "../data"
    },
    markdownTemplateEngine: "njk",
    dataTemplateEngine: "njk",
    htmlTemplateEngine: "njk"
  };
};
