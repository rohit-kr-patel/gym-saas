const { defineConfig, globalIgnores } = require('eslint/config');
const expoConfig = require('eslint-config-expo/flat');
const prettierRecommended = require('eslint-plugin-prettier/recommended');

module.exports = defineConfig([
  globalIgnores(['node_modules/**', '.expo/**', 'dist/**', 'coverage/**']),
  expoConfig,
  prettierRecommended,
]);
