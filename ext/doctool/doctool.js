/*
  Process a single doc file

    argv[2] = template file
    argv[3] = input file
    argv[4] = output file
*/
var fs = require("fs"),
    path = require("path"),
    markdown = require("./markdown"),
    argv = process.argv,
    argc = argv.length;

var template = fs.readFileSync(argv[2], "utf8");

function backpath(p1, p2) {
  p1 = path.dirname(path.normalize(p1));
  p2 = path.dirname(path.normalize(p2));
  if(p2.length <=  p1.length)
    return "" // also handles README files from parent directory
  return p2.replace(p1, "").replace(/[\/\\]([^\/\\])+/g, "../");
}

var docroot = backpath(argv[2], argv[3]);

function formatIdString(str) {
  str = str
    .replace(/\([^)}]*\)/gmi, "")
    .replace(/[^A-Za-z0-9_.]+/gmi, "_");

  return str.substr(0,1).toLowerCase() + str.substr(1);
}

function cap(name) {
  return name.replace( /(^| )([a-z])/g , function(m,p1,p2){ return p1+p2.toUpperCase(); } );
}

function filenameToTitle(fn) {
  return '<h1>' + cap(fn.replace('_', " ")) + '</h1>';
}

function generateToc(data) {
  var last_level = 0
    , first_level = 0
    , toc = [
      '<div id="toc">',
      '<h2>Table of Contents</h2>',
      '<ul><li><a href="'+docroot+'index.html">Back to Overview ...</a></li></ul>'
    ];

  data.replace(/(^#+)\W+([^$\n]+)/gmi, function(src, level, text) {
    level = level.length;

    if (first_level == 0) first_level = level;

    if (level <= last_level) {
      toc.push("</li>");
    }

    if (level > last_level) {
      toc.push("<ul>");
    } else if (level < last_level) {
      for(var c=last_level-level; 0 < c ; c-- ) {
        toc.push("</ul>");
        toc.push("</li>");
      }
    }

    toc.push("<li>");
    toc.push('<a href="#'+formatIdString(text)+'">'+text+'</a>');

    last_level = level;
  });

  for(var c=last_level-first_level; 0 <= c ; c-- ) {
    toc.push("</li>");
    toc.push("</ul>");
  }

  toc.push("</div>");

  return toc.join("");
}


var includeExpr = /^@include\s+([A-Za-z0-9-_]+)(?:\.)?([a-zA-Z]*)$/gmi;
// Allow including other pages in the data.
function loadIncludes(data, current_file) {
  return data.replace(includeExpr, function(src, name, ext) {
    try {
      var include_path = path.join(current_file, "../", name+"."+(ext || "md"))
      return loadIncludes(fs.readFileSync(include_path, "utf8"), current_file);
    } catch(e) {
      return "";
    }
  });
}


function convertData(data) {
  // Convert it to HTML from Markdown
  var html = markdown.toHTML(markdown.parse(data), {xhtml:true})
    .replace(/<hr><\/hr>/g, "<hr />")
    .replace(/(\<h[2-6])\>([^<]+)(\<\/h[1-6]\>)/gmi, function(o, ts, c, te) {
      return ts+' id="'+formatIdString(c)+'">'+c+te;
    });

  return html;
}


if (argc > 3) {
  var filename = argv[3],
      output = template,
      html,
      toc;

  fs.readFile(filename, "utf8", function(err, data) {
    if (err) throw err;

    // go recursion.
    data = loadIncludes(data, filename);
    // go markdown.
    html = convertData(data);
    toc = "";
    filename = path.basename(filename, ".md");

    if (filename != "_toc" && filename != "index") {
      if (data) {
        toc = generateToc(data);
      }
      output = output.replace("{{section}}", filename+" - ");
      output = output.replace("{{section-title}}", filenameToTitle(filename));
      output = output.replace("{{toc}}", toc);
      output = output.replace("{{content}}", html);
    } else {
      output = output.replace("{{section}}", "");
      output = output.replace("{{section-title}}", "");
      //output = output.replace(/<body([^>]*)>/, '<body class="'+filename+'" $1>');
      output = output.replace("{{toc}}", html);
      output = output.replace("{{content}}", "");
    }
    output = output.replace(/\{\{docroot\}\}/g, docroot);
    
    if (html.length == 0) {
      html = "Sorry, this section is currently undocumented, \
but we'll be working on it.";
    }

    if (argc > 4) {
      fs.writeFile(argv[4], output);
    } else {
      process.stdout.write(output);
    }
  });
}
