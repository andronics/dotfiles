# [PROJECT_NAME] Repository Guide for Claude Code

## Repository Overview

**Purpose**: [Brief description of what this project/package does and its main use case]

**Repository**: [GitHub/GitLab URL]  
**Documentation**: [Official documentation URL if different from repo]  
**Owner/Organization**: [Owner name or organization]  
**License**: [License type - MIT, GPL, Apache, etc.]  
**Current Version**: [Latest version number]  
**Primary Language**: [Main programming language]  
**Package Manager**: [npm, yarn, pnpm, pip, cargo, etc.]  

## Technology Stack

### Primary Technologies
- **[Framework/Runtime]**: [Version] - [Brief description of role]
- **[Language]**: [Version] - [Type system, compilation details]
- **[Build System]**: [Tool name] - [Purpose: bundling, compilation, etc.]
- **[Database/Storage]**: [Technology] - [Purpose and configuration]

### Key Dependencies
```json
{
  "dependency1": "version - purpose",
  "dependency2": "version - purpose",
  "dependency3": "version - purpose"
}
```
*Or format as bullet points for non-JSON package managers*

### Development & Quality Tools
- **[Linter]**: [Tool name] - [Configuration details]
- **[Formatter]**: [Tool name] - [Style configuration]
- **[Testing Framework]**: [Tool name] - [Testing approach]
- **[Type Checker]**: [Tool name] - [Configuration]
- **[CI/CD]**: [Platform] - [Pipeline details]

## Directory Structure

```
project-name/
├── src/                        # Main source code
│   ├── components/             # Reusable components
│   ├── utils/                  # Utility functions
│   ├── types/                  # Type definitions
│   ├── config/                 # Configuration files
│   └── [module-name]/          # Feature-specific modules
│       ├── index.ts            # Module entry point
│       ├── [component].ts      # Component implementation
│       └── types.ts            # Module-specific types
├── tests/                      # Test files
│   ├── unit/                   # Unit tests
│   ├── integration/            # Integration tests
│   └── e2e/                    # End-to-end tests
├── docs/                       # Documentation
├── examples/                   # Usage examples
├── scripts/                    # Build/deployment scripts
├── package.json                # Dependencies and scripts
├── tsconfig.json              # TypeScript configuration
├── [config-file]              # Framework-specific config
└── README.md                  # Project documentation
```

## Development Workflow

### Essential Commands

#### Setup & Development
```bash
# Initial setup
[package-manager] install              # Install dependencies
[setup-command]                        # Additional setup if needed

# Development
[package-manager] dev                  # Start development server
[package-manager] start                # Alternative start command
[package-manager] watch                # Watch mode for development

# Building
[package-manager] build                # Build for production
[package-manager] compile              # Compilation step
```

#### Code Quality & Testing
```bash
# Linting and formatting
[package-manager] lint                 # Check code style
[package-manager] lint:fix             # Auto-fix linting issues
[package-manager] format               # Format code
[package-manager] format:check         # Check formatting

# Type checking
[package-manager] typecheck            # TypeScript type checking
[package-manager] types                # Alternative type check command

# Testing
[package-manager] test                 # Run all tests
[package-manager] test:unit            # Run unit tests
[package-manager] test:integration     # Run integration tests
[package-manager] test:e2e             # Run end-to-end tests
[package-manager] test:watch           # Run tests in watch mode
[package-manager] test:coverage        # Run tests with coverage
```

#### Deployment & Release
```bash
# Building for production
[package-manager] build:prod           # Production build
[package-manager] bundle               # Bundle assets

# Release management
[package-manager] version              # Version management
[package-manager] publish              # Publish package
[package-manager] release              # Release workflow
```

### Development Environment Setup

1. **Prerequisites**: 
   - [Runtime/Language] [version requirement]
   - [Tool] [version requirement]
   - [System dependency] [installation notes]

2. **Installation Process**:
   ```bash
   # Clone repository
   git clone [repository-url]
   cd [project-name]
   
   # Install dependencies
   [installation-commands]
   
   # Initial setup
   [setup-commands]
   ```

3. **IDE Configuration**:
   - **VS Code**: [Extensions, settings, launch configurations]
   - **[Other IDE]**: [Configuration details]

## Critical Development Guidelines

### Code Standards & Patterns

1. **[Standard 1]**: [Description and reasoning]
2. **[Standard 2]**: [Description with examples]
3. **API Design**: [Principles for public API design]
4. **Error Handling**: [Error handling patterns and conventions]
5. **Testing Strategy**: [Testing approaches and requirements]

### Architecture Patterns

1. **[Pattern Name]**: [Description of architectural pattern used]
   - [Implementation details]
   - [When to use this pattern]
   - [Examples of usage]

2. **State Management**: [How application state is managed]
   - [State management library/approach]
   - [State structure]
   - [Update patterns]

3. **Module Organization**: [How code is organized into modules]
   - [Module boundaries]
   - [Import/export patterns]
   - [Dependency management]

### Git & PR Guidelines

- **Commit Convention**: [Commit message format and examples]
- **Branch Strategy**: [Branching model and naming conventions]
- **PR Requirements**: [Review process, checks, documentation updates]
- **Release Process**: [How releases are managed and versioned]

### Performance Considerations

- **[Performance Concern 1]**: [Description and mitigation strategies]
- **[Performance Concern 2]**: [Monitoring and optimization approaches]
- **Benchmarking**: [Performance testing approach]

## Architecture & Patterns

### Core Architectural Concepts

#### 1. [Architecture Pattern Name]
[Description of the main architectural pattern]

```typescript
// Example code showing the pattern
interface ExampleInterface {
  property: Type;
  method(): ReturnType;
}
```

#### 2. [Secondary Pattern]
[Description of supporting architectural patterns]

### Extension Points

#### [Extension Type 1]
[How to extend or customize this aspect]

```typescript
// Example extension code
```

#### [Extension Type 2]
[How to extend or customize this aspect]

### Communication Patterns

- **[Pattern 1]**: [How components/modules communicate]
- **[Pattern 2]**: [Data flow patterns]
- **Events**: [Event system if applicable]
- **APIs**: [Internal or external API patterns]

## Common Development Tasks

### Adding New Features

1. **Planning**: [How to plan new features]
2. **Implementation**: [Step-by-step implementation guide]
3. **Testing**: [Testing requirements for new features]
4. **Documentation**: [Documentation updates needed]
5. **Integration**: [How to integrate with existing code]

### Creating [Component/Module Type]

```[language]
// Template for creating new components/modules
[example-code]
```

### Testing Procedures

1. **Unit Testing**: [Approach and patterns]
2. **Integration Testing**: [How to test component interactions]
3. **E2E Testing**: [End-to-end testing strategy]
4. **Mock Strategy**: [How to mock dependencies]

### Debugging & Troubleshooting

1. **Debug Setup**: [How to set up debugging]
2. **Common Issues**: [Frequently encountered problems]
3. **Debug Tools**: [Tools and techniques for debugging]
4. **Performance Debugging**: [Profiling and optimization]

### Deployment Process

1. **Build Process**: [How builds are created]
2. **Environment Configuration**: [Environment-specific settings]
3. **Release Pipeline**: [Automated deployment process]
4. **Rollback Procedures**: [How to handle failed deployments]

## Meta-Optimization for Claude Code

### Priority Files to Read First

**High Priority** (essential understanding):
1. `[file-path]` - [Brief description of importance]
2. `[file-path]` - [Brief description of importance]
3. `[file-path]` - [Brief description of importance]

**Medium Priority** (context-dependent):
1. `[file-path]` - [When to read this file]
2. `[file-path]` - [Specific use cases]
3. `[file-path]` - [Conditional importance]

**Lower Priority** (reference):
1. `[file-path]` - [Reference material]
2. `[file-path]` - [Configuration files]

### Decision Trees

**When [doing task X]**:
1. Check if [condition] → [action]
2. If [condition] → [action]
3. Otherwise → [default action]

**When [debugging issue Y]**:
1. First check [common cause] → [solution]
2. If not resolved, check [next cause] → [solution]
3. For complex issues → [escalation path]

### Code Patterns to Follow

#### [Pattern Name]
```[language]
// Template showing preferred pattern
[example-code-with-explanation]
```

#### [Another Pattern]
```[language]
// Another important pattern
[example-code-with-explanation]
```

### Common Pitfalls to Avoid

- **[Pitfall 1]**: [Description and how to avoid]
- **[Pitfall 2]**: [Common mistake and prevention]
- **[Pitfall 3]**: [Performance or security concern]

### Extension Patterns

- **[Extension Type]**: [How to properly extend functionality]
- **Plugin Architecture**: [If applicable, how plugins work]
- **Customization Points**: [Where and how to customize]

## External Resources

### Official Documentation
- **Main Docs**: [URL]
- **API Reference**: [URL]
- **Tutorials**: [URL]
- **Examples**: [URL]

### Community Resources
- **Community Forum/Discord**: [URL]
- **GitHub Discussions**: [URL]
- **Stack Overflow Tag**: [Tag name]

### Learning Resources
- **Getting Started Guide**: [URL]
- **Advanced Tutorials**: [URL]
- **Best Practices**: [URL]
- **Migration Guides**: [URL if applicable]

## Quick Reference & Cheat Sheet

### Essential Commands
```bash
# Most commonly used commands
[command] # [description]
[command] # [description]
```

### Key Concepts
- **[Concept]**: [Brief explanation]
- **[Concept]**: [Brief explanation]
- **[Concept]**: [Brief explanation]

### Common Patterns
```[language]
// Most frequently used code patterns
[pattern-1]
[pattern-2]
```

### Troubleshooting Quick Fixes
- **Issue**: [Quick solution]
- **Issue**: [Quick solution]
- **Issue**: [Quick solution]

---

*This template provides a comprehensive structure for documenting any software project or package. Customize sections based on the specific technology stack and project requirements.*