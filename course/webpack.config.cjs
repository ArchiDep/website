const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const { WebpackManifestPlugin } = require('webpack-manifest-plugin');
const path = require('path');

const production = process.env.NODE_ENV === 'production';

const baseConfig = {
  devtool: 'source-map',
  mode: production ? 'production' : 'development',
  resolve: {
    extensions: ['.js', '.ts']
  }
};

module.exports = [
  {
    ...baseConfig,
    entry: {
      course: './src/assets/course.ts',
      slides: './src/assets/slides.ts'
    },
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
          test: /\.template\.html$/u,
          type: 'asset/source'
        },
        {
          test: /\.ts$/,
          use: {
            loader: 'ts-loader',
            options: {
              configFile: 'tsconfig.assets.json'
            }
          },
          exclude: /node_modules/
        }
      ]
    },
    output: {
      filename: production ? '[name].[chunkhash].js' : '[name].js',
      path: path.resolve(
        __dirname,
        '..',
        'app',
        'priv',
        'static',
        'assets',
        'course'
      ),
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
  },
  {
    ...baseConfig,
    entry: {
      search: './src/assets/course/search.ts'
    },
    module: {
      rules: [
        {
          test: /\.template\.html$/u,
          type: 'asset/source'
        },
        {
          test: /\.ts$/,
          use: {
            loader: 'ts-loader',
            options: {
              configFile: 'tsconfig.assets.json'
            }
          },
          exclude: /node_modules/
        }
      ]
    },
    output: {
      filename: '[name].js',
      path: path.resolve(
        __dirname,
        '..',
        'app',
        'priv',
        'static',
        'assets',
        'search'
      ),
      publicPath: '/assets/search/'
    }
  }
];
