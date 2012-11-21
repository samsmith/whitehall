var page = new WebPage(),
    address, output, width, height, javaScript;

if (phantom.args.length < 3 || phantom.args.length > 5) {
  console.log('Usage: screenshot.js URL width height filename');
  phantom.exit();
} else {
  address = phantom.args[0];
  width = phantom.args[1];
  height = phantom.args[2];
  output = phantom.args[3];
  if (phantom.args.length > 4) {
    javaScript = phantom.args[4];
  }
  page.viewportSize = { width: width, height: height };
  page.paperSize = { width: '300px', height: '200px', border: '0px' };
  page.open(address, function (status) {
    if (status !== 'success') {
      console.log('Unable to load the address "' + address + '"');
      phantom.exit(1);
    } else {
      window.setTimeout(function () {
        if (javaScript) {
          page.evaluate(function(script) {
            eval(script);
          },javaScript);
        }
        page.render(output);
        phantom.exit();
      }, 1000);
    }
  });
}
