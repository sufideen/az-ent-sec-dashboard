const React = require("react");
const ReactDOMServer = require("react-dom/server");
const sharp = require("sharp");
const fa = require("react-icons/fa");
const fa6 = require("react-icons/fa6");

// Renders a react-icons icon to a base64 PNG data URI at the given size/color.
async function iconPng(IconComponent, color, sizePx = 256) {
  const svgString = ReactDOMServer.renderToStaticMarkup(
    React.createElement(IconComponent, { size: sizePx, color: `#${color}` })
  );
  const buf = await sharp(Buffer.from(svgString), { density: 300 })
    .resize(sizePx, sizePx)
    .png()
    .toBuffer();
  return "image/png;base64," + buf.toString("base64");
}

module.exports = { iconPng, fa, fa6 };
