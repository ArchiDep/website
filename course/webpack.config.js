const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const { WebpackManifestPlugin } = require('webpack-manifest-plugin');
const path = require('path');

const production = process.env.NODE_ENV === 'production';

module.exports = {
  entry: {
    course: './src/assets/course.js',
    slides: './src/assets/slides.js'
  },
  mode: production ? 'production' : 'development',
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
    filename: production ? '[name].[chunkhash].js' : '[name].js',
    path: path.resolve(__dirname, '..', 'app', 'priv', 'static', 'assets', 'course'),
    publicPath: '/assets/course/'
  },
  plugins: [
    new MiniCssExtractPlugin({
      filename: production ? '[name].[chunkhash].css' : '[name].css'
    }),
    new WebpackManifestPlugin({
      basePath: '/assets/course/'
    })
  ]
};
