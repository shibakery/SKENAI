# SKENAI Documentation Search Guide

## Quick Search Reference

### 🔍 Common Search Topics

#### Getting Started
- `setup`, `installation`, `prerequisites`
- `quickstart`, `tutorial`, `guide`
- `configuration`, `settings`
- `requirements`, `dependencies`

#### Development
- `contracts`, `smart contracts`, `solidity`
- `deployment`, `testing`, `debugging`
- `api`, `integration`, `interfaces`
- `security`, `audit`, `vulnerabilities`

#### Operations
- `monitoring`, `maintenance`, `updates`
- `performance`, `optimization`, `scaling`
- `troubleshooting`, `errors`, `fixes`
- `backup`, `recovery`, `restoration`

#### Governance
- `proposals`, `voting`, `delegation`
- `parameters`, `settings`, `configuration`
- `roles`, `permissions`, `access`
- `emergency`, `security`, `incidents`

## Search Methods

### 1. Documentation Index Search

#### Using the Index
1. Start at [INDEX.md](./INDEX.md)
2. Use browser search (Ctrl+F/Cmd+F)
3. Navigate through categories
4. Follow relevant links

#### Index Categories
```
📚 Core Documentation
 ├── 🌟 Getting Started
 ├── 📖 Technical Documentation
 ├── 👥 User Documentation
 ├── 🚀 Deployment Documentation
 ├── 🔒 Security Documentation
 └── 🛠️ Support Documentation
```

### 2. GitHub Repository Search

#### Repository Search
1. Visit the [SKENAI Repository](https://github.com/your-org/skenai)
2. Use GitHub search bar
3. Filter by:
   - Path: `/docs`
   - Extension: `.md`
   - Filename
   - Content

#### Search Syntax
```
# Search in docs directory
path:docs your-search-term

# Search markdown files
extension:md your-search-term

# Search specific file
filename:TECHNICAL_SPECIFICATION.md your-search-term

# Combine filters
path:docs extension:md "error handling"
```

### 3. Local Documentation Search

#### Using ripgrep (recommended)
```bash
# Search all documentation
rg "search term" ./docs

# Search specific files
rg "api" ./docs/*GUIDE.md

# Case-insensitive search
rg -i "security" ./docs

# Search with context
rg -C 3 "deployment" ./docs
```

#### Using grep
```bash
# Basic search
grep -r "search term" ./docs

# Case-insensitive
grep -ri "api" ./docs

# Show line numbers
grep -rn "security" ./docs
```

## Search Tips

### 1. Keyword Selection

#### Technical Terms
- Use precise technical terms
- Include common abbreviations
- Try alternative spellings
- Use both singular and plural

#### Examples
```
# Good searches
"gas optimization"
"access control"
"error handling"

# Better searches
"gas optimization techniques"
"RBAC access control"
"error handling best practices"
```

### 2. Context Refinement

#### Narrowing Results
- Add specific context
- Use technical prefixes
- Include component names
- Specify actions

#### Examples
```
# Too broad
"deployment"

# Better focused
"smart contract deployment"
"mainnet deployment steps"
"deployment security checks"
```

### 3. Documentation Sections

#### Common Sections
```
# Technical sections
"Architecture"
"Implementation"
"Integration"
"API Reference"

# Operational sections
"Configuration"
"Deployment"
"Monitoring"
"Maintenance"

# Security sections
"Access Control"
"Audit"
"Emergency"
"Recovery"
```

## Search Scenarios

### 1. Finding Implementation Details
```
# Search pattern
path:docs/technical "implementation" AND ("pattern" OR "example")

# Specific components
filename:TECHNICAL_SPECIFICATION.md "Agent Registry"
```

### 2. Troubleshooting Issues
```
# Error search
path:docs/troubleshooting "error" AND "solution"

# Common problems
filename:TROUBLESHOOTING_GUIDE.md "common issues"
```

### 3. Security Information
```
# Security features
path:docs/security "feature" AND "configuration"

# Emergency procedures
filename:EMERGENCY_CONTACTS.md "procedure"
```

## Quick Reference Links

### Documentation Maps
- [Documentation Index](./INDEX.md)
- [Technical Documentation](./TECHNICAL_SPECIFICATION.md)
- [User Documentation](./USER_GUIDE.md)
- [API Documentation](./API_REFERENCE.md)

### Common Searches
1. Setup & Installation
   - [Prerequisites](./DEPLOYMENT_GUIDE.md#prerequisites)
   - [Configuration](./DEPLOYMENT_GUIDE.md#configuration)
   - [Quick Start](./USER_GUIDE.md#quick-start)

2. Development
   - [API Reference](./API_REFERENCE.md)
   - [Integration Guide](./INTEGRATION_GUIDE.md)
   - [Security Guidelines](./SECURITY_GUIDELINES.md)

3. Operations
   - [Monitoring Guide](./ADMIN_GUIDE.md#monitoring)
   - [Maintenance](./ADMIN_GUIDE.md#maintenance)
   - [Troubleshooting](./TROUBLESHOOTING_GUIDE.md)

## Search Support

### Getting Help
- [Discord Support](https://discord.gg/skenai)
- [GitHub Issues](https://github.com/your-org/skenai/issues)
- [Documentation Updates](./INDEX.md#documentation-updates)

### Contributing
- Found missing information?
- Want to improve search?
- Have suggestions?

Visit our [Contributing Guide](../CONTRIBUTING.md) to help improve the documentation.
