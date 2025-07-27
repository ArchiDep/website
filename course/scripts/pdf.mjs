import puppeteer from 'puppeteer';

const browser = await puppeteer.launch();
const page = await browser.newPage();

await page.goto('http://localhost:42000/course/101-command-line/slides/?print-pdf', {
  waitUntil: 'networkidle2'
});

await page.bringToFront();

// Saves the PDF to hn.pdf.
await page.pdf({
  // margin: {
  //   top: '1cm',
  //   right: '1cm',
  //   bottom: '1cm',
  //   left: '1cm'
  // },
  path: 'test.pdf',
  preferCSSPageSize: true,
  printBackground: true,
  waitForFonts: true
});

await browser.close();
