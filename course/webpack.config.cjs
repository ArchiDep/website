const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const path = require('path');

const production = process.env.NODE_ENV === 'production';
const basePath = process.env.ARCHIDEP_BASE_PATH ?? '';

const baseConfig = {
  devtool: 'source-map',
  mode: production ? 'production' : 'development',
  resolve: {
    alias: {
      react: 'preact/compat',
      'react-dom/test-utils': 'preact/test-utils',
      'react-dom': 'preact/compat', // Must be below test-utils
      'react/jsx-runtime': 'preact/jsx-runtime'
    },
    extensions: ['.js', '.ts', '.tsx']
  }
};

module.exports = [
  {
    ...baseConfig,
    entry: {
      course: './src/assets/course.ts',
      'slides-mermaid': '/src/assets/slides-mermaid.ts',
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
          test: /\.tsx?$/,
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
      // Entry bundles are named plainly and cache-busted by `mix phx.digest`,
      // which is the site's single asset manifest. Chunks loaded at runtime
      // are not: the webpack runtime requests them by name from `publicPath`,
      // so they never go through a manifest and carry their own content hash.
      filename: '[name].js',
      chunkFilename: production ? '[id].[chunkhash].js' : '[id].js',
      path: path.resolve(
        __dirname,
        '..',
        'app',
        'priv',
        'static',
        'assets',
        'course'
      ),
      publicPath: `${basePath}/assets/course/`
    },
    plugins: [
      new MiniCssExtractPlugin({
        filename: '[name].css',
        chunkFilename: production ? '[id].[chunkhash].css' : '[id].css'
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
          test: /\.tsx?$/,
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
      publicPath: `${basePath}/assets/search/`
    }
  }
];
