const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const { WebpackManifestPlugin } = require('webpack-manifest-plugin');
const path = require('path');

const production = process.env.NODE_ENV === 'production';

module.exports = {
  entry: {
    course: './src/assets/course.ts',
    slides: './src/assets/slides.ts'
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
      },
      {
        test: /\.tsx?$/,
        use: 'ts-loader',
        exclude: /node_modules/,
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
  ],
  resolve: {
    extensions: ['.js', '.ts']
  }
};
