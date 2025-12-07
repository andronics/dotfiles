# Claude AI Integration for Docker Stack Manager

This directory contains specialized Claude agents and commands designed specifically for the Docker Stack Manager (`dckr`) project.

## Directory Structure

```
.claude/
├── agents/           # Specialized AI agents for different aspects
│   ├── docker-stack-analyzer.md      # Stack analysis and optimization
│   ├── docker-stack-builder.md       # Stack creation and modification
│   ├── docker-troubleshooter.md      # Issue diagnosis and resolution
│   └── docker-script-enhancer.md     # Tool enhancement and features
├── commands/         # Quick commands for common operations
│   ├── analyze-stack.md     # /analyze-stack command
│   ├── build-stack.md       # /build-stack command
│   ├── debug-stack.md       # /debug-stack command
│   ├── enhance-dckr.md      # /enhance-dckr command
│   ├── quick-fix.md         # /quick-fix command
│   └── stack-health.md      # /stack-health command
└── README.md         # This file
```

## Specialized Agents

### 1. Docker Stack Analyzer
**Purpose:** Deep analysis of Docker stacks for performance, security, and architecture
- Analyzes service configurations and dependencies
- Identifies bottlenecks and optimization opportunities
- Reviews security configurations
- Maps service relationships

### 2. Docker Stack Builder
**Purpose:** Creation and modification of Docker compose stacks
- Generates production-ready docker-compose.yml files
- Implements security best practices
- Sets up proper networking and volume management
- Creates comprehensive documentation

### 3. Docker Troubleshooter
**Purpose:** Diagnosis and resolution of Docker stack issues
- Analyzes container logs and failures
- Debugs network and connectivity problems
- Resolves volume and storage issues
- Investigates service dependency problems

### 4. Docker Script Enhancer
**Purpose:** Enhancement and extension of the dckr tool itself
- Adds new features and commands
- Optimizes performance and efficiency
- Improves user experience
- Integrates with external tools

## Quick Commands

### Stack Management Commands
- `/analyze-stack <name>` - Comprehensive stack analysis
- `/build-stack <name> [template]` - Create or modify stacks
- `/debug-stack <name> [issue-type]` - Troubleshoot specific issues
- `/stack-health [name|all]` - Health check and status report

### Tool Enhancement Commands
- `/enhance-dckr <feature> <description>` - Add features to dckr tool
- `/quick-fix <name> [type]` - Apply common fixes automatically

## Usage Examples

```bash
# Analyze the media stack for performance issues
/analyze-stack media

# Create a new web application stack
/build-stack myapp web

# Debug startup issues with authentik stack
/debug-stack authentik startup

# Check health of all stacks
/stack-health all

# Add caching feature to dckr tool
/enhance-dckr performance "Implement API call caching"

# Quick restart and cleanup of problematic stack
/quick-fix traefik restart
```

## Integration with dckr Tool

These Claude agents and commands are designed to work seamlessly with the `dckr` command-line tool described in `../CLAUDE.md`. They provide:

1. **Intelligent Analysis** - Beyond basic container listing
2. **Automated Problem Solving** - Proactive issue resolution
3. **Best Practice Implementation** - Security and performance optimization
4. **Continuous Improvement** - Tool enhancement and feature addition

## Agent Capabilities

Each agent has access to appropriate tools:
- **File Operations:** Read, Write, Edit, MultiEdit
- **Search Operations:** Grep, Glob
- **System Operations:** Bash commands
- **Web Operations:** WebFetch for documentation and best practices

## Best Practices

1. **Use Specific Agents** - Choose the right agent for your task
2. **Provide Context** - Include stack names and specific issues
3. **Follow Recommendations** - Agents provide actionable advice
4. **Validate Changes** - Always review before applying modifications
5. **Document Changes** - Keep track of modifications and improvements

## Contributing

When adding new agents or commands:
1. Follow the established markdown format
2. Include clear descriptions and usage examples
3. Specify appropriate tool access for agents
4. Update this README with new additions
5. Test functionality with actual Docker stacks

---

This Claude integration transforms the basic `dckr` tool into an intelligent Docker stack management system with AI-powered analysis, troubleshooting, and optimization capabilities.