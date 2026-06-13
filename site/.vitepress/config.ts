import { defineConfig } from 'vitepress';

export default defineConfig({
  base: '/solace-squads-smart-accounts/',
  title: 'Solace · Squads Smart Accounts',
  description: 'A Ruby toolkit for the Squads Smart Account program on Solana, built on Solace',
  lang: 'en-US',
  cleanUrls: true,
  lastUpdated: true,
  appearance: false,
  vite: {
    server: {
      allowedHosts: true,
    },
  },
  themeConfig: {
    siteTitle: 'Squads Smart Accounts',
    search: {
      provider: 'local',
    },
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Quick Start', link: '/getting-started/' },
      { text: 'Concepts', link: '/concepts/settings-vs-smart-account' },
      { text: 'Guides', link: '/guides/create-a-smart-account' },
      { text: 'Reference', link: '/reference/program-client' },
    ],
    sidebar: [
      {
        text: 'Introduction',
        items: [
          { text: 'Overview', link: '/' },
          { text: 'Quick Start', link: '/getting-started/' },
        ],
      },
      {
        text: 'Concepts',
        items: [
          { text: 'Settings vs. Smart Account', link: '/concepts/settings-vs-smart-account' },
          { text: 'Permissions & Threshold', link: '/concepts/permissions-and-threshold' },
          { text: 'The Async Transaction Lifecycle', link: '/concepts/async-transaction-lifecycle' },
          { text: 'Spending Limits', link: '/concepts/spending-limits' },
        ],
      },
      {
        text: 'Guides',
        items: [
          { text: 'Create a Smart Account', link: '/guides/create-a-smart-account' },
          { text: 'Vault Transactions', link: '/guides/vault-transactions' },
          { text: 'Settings Transactions', link: '/guides/settings-transactions' },
          { text: 'Synchronous Execution', link: '/guides/synchronous-execution' },
        ],
      },
      {
        text: 'Reference',
        items: [
          { text: 'Program Client', link: '/reference/program-client' },
          { text: 'Instruction Coverage', link: '/reference/instruction-coverage' },
        ],
      },
    ],
    socialLinks: [
      { icon: 'github', link: 'https://github.com/zarpay/solace-squads-smart-accounts' },
    ],
    outline: {
      level: [2, 3],
      label: 'On this page',
    },
    docFooter: {
      prev: 'Previous page',
      next: 'Next page',
    },
    footer: {
      message: 'Built on <a href="https://github.com/sebscholl/solace">Solace</a>',
      copyright: 'Released under the MIT License',
    },
  },
});
