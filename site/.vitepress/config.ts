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
      { text: 'Operations', link: '/operations/create-smart-account' },
      { text: 'Reference', link: '/reference/pda-and-fetchers' },
    ],
    sidebar: [
      {
        text: 'Introduction',
        items: [
          { text: 'Overview', link: '/' },
          { text: 'Quick Start', link: '/getting-started/' },
          { text: 'Conventions', link: '/conventions' },
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
        text: 'Account',
        items: [
          { text: 'Create a Smart Account', link: '/operations/create-smart-account' },
        ],
      },
      {
        text: 'Authority Actions',
        items: [
          { text: 'Add a Signer', link: '/operations/authority/add-signer' },
          { text: 'Remove a Signer', link: '/operations/authority/remove-signer' },
          { text: 'Change the Threshold', link: '/operations/authority/change-threshold' },
          { text: 'Set the Time Lock', link: '/operations/authority/set-time-lock' },
          { text: 'Set a New Settings Authority', link: '/operations/authority/set-new-settings-authority' },
        ],
      },
      {
        text: 'Spending Limits',
        items: [
          { text: 'Add a Spending Limit', link: '/operations/spending-limits/add' },
          { text: 'Use a Spending Limit', link: '/operations/spending-limits/use' },
          { text: 'Remove a Spending Limit', link: '/operations/spending-limits/remove' },
        ],
      },
      {
        text: 'Vault Transactions',
        items: [
          { text: 'Create a Transaction', link: '/operations/vault/create-transaction' },
          { text: 'Create a Proposal', link: '/operations/vault/create-proposal' },
          { text: 'Activate a Proposal', link: '/operations/vault/activate-proposal' },
          { text: 'Approve a Proposal', link: '/operations/vault/approve-proposal' },
          { text: 'Reject a Proposal', link: '/operations/vault/reject-proposal' },
          { text: 'Cancel a Proposal', link: '/operations/vault/cancel-proposal' },
          { text: 'Execute a Transaction', link: '/operations/vault/execute-transaction' },
          { text: 'Close a Transaction', link: '/operations/vault/close-transaction' },
        ],
      },
      {
        text: 'Settings Transactions',
        items: [
          { text: 'Create a Settings Transaction', link: '/operations/settings/create' },
          { text: 'Execute a Settings Transaction', link: '/operations/settings/execute' },
          { text: 'Close a Settings Transaction', link: '/operations/settings/close' },
          { text: 'Execute Synchronously', link: '/operations/settings/execute-sync' },
        ],
      },
      {
        text: 'Synchronous Execution',
        items: [
          { text: 'Execute a Transaction (sync)', link: '/operations/execute-transaction-sync' },
        ],
      },
      {
        text: 'Reference',
        items: [
          { text: 'PDA Derivation & Fetchers', link: '/reference/pda-and-fetchers' },
          { text: 'Vault Address Lookup', link: '/reference/vault-index-lookup' },
          { text: 'Account Types', link: '/reference/account-types' },
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
