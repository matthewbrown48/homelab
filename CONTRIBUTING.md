# Contributing to Homelab GitOps

Thank you for your interest in this project!

## Using This Template

This is a portfolio/template project for GitOps homelab infrastructure. Here's how you can use it:

### For Your Own Homelab

1. **Fork or Use Template**
   - Click "Use this template" on GitHub, or
   - Fork the repository to your account

2. **Clone Locally**
   ```bash
   git clone https://github.com/YOUR_USERNAME/homelab.git
   cd homelab
   ```

3. **Follow Setup Guide**
   - See [QUICKSTART.md](QUICKSTART.md) for quick setup
   - See [docs/getting-started.md](docs/getting-started.md) for detailed guide

4. **Customize**
   - Replace example IPs with your device IPs
   - Configure `.env` files from `.env.example` templates
   - Adjust docker-compose.yml files for your services

### For Learning/Reference

- Browse the code to learn about GitOps patterns
- Check out the GitHub Actions workflows
- Study the Docker Compose configurations
- Review the documentation structure

## Reporting Issues

Found a bug or issue? Please:

1. **Check existing issues** first to avoid duplicates
2. **Use issue templates** when available
3. **Include details**:
   - What you expected to happen
   - What actually happened
   - Steps to reproduce
   - Your environment (OS, Docker version, etc.)
   - Relevant logs or error messages

## Suggesting Improvements

Have an idea? Great!

1. **Open a Discussion** first for major changes
2. **Create an Issue** for specific improvements
3. **Be descriptive** about the benefit and use case

## Pull Requests

Want to contribute code?

### What We Accept

✅ **Bug fixes**: Clear bug with reproduction steps
✅ **Documentation**: Typos, clarifications, examples
✅ **Examples**: New device configs, service additions
✅ **Scripts**: Useful automation or helper scripts

### What to Avoid

❌ **Personal configurations**: Keep your specific IPs, passwords, etc.
❌ **Breaking changes**: Major architectural changes without discussion
❌ **Secrets**: Never commit real secrets or credentials

### PR Process

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes**
   - Follow existing code style
   - Update documentation if needed
   - Test your changes

4. **Commit with clear messages**
   ```bash
   git commit -m "Add: feature description"
   ```

5. **Push and create PR**
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Describe your changes** in the PR description

### Commit Message Guidelines

Use prefixes to categorize commits:

- `Add:` New feature or file
- `Fix:` Bug fix
- `Update:` Modify existing feature
- `Docs:` Documentation only
- `Refactor:` Code refactoring
- `Test:` Adding tests
- `Security:` Security-related changes

Examples:
```
Add: Radarr service to Jellyfin server
Fix: Traefik SSL certificate renewal issue
Docs: Update Tailscale setup instructions
Update: Woodpecker CI to latest version
```

## Code of Conduct

### Our Standards

- Be respectful and inclusive
- Welcome newcomers
- Accept constructive criticism
- Focus on what's best for the community
- Show empathy towards others

### Not Acceptable

- Harassment or discriminatory language
- Trolling or insulting comments
- Publishing others' private information
- Other unprofessional conduct

## Questions?

- **General questions**: Open a Discussion
- **Bug reports**: Create an Issue
- **Security issues**: See [SECURITY.md](SECURITY.md) if created, or create a private issue

## Attribution

This project is maintained as a portfolio/template project. All contributors will be acknowledged in the project README.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

**Thank you for helping make this project better!** 🚀
