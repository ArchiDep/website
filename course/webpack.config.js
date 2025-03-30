const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const path = require('path');

module.exports = {
  entry: './src/assets/course.js',
  mode: process.env.NODE_ENV === 'production' ? 'production' : 'development',
  module: {
    rules: [
      {
        test: /\.css$/u,
        use: [
          MiniCssExtractPlugin.loader,
          { loader: 'css-loader', options: { sourceMap: false } }
        ]
      }
    ]
  },
  output: {
    filename: 'course.js',
    path: path.resolve(__dirname, '..', 'app', 'priv', 'static', 'assets'),
  },
  plugins: [
    new MiniCssExtractPlugin({
      filename: 'course.css'
    })
  ]
};
