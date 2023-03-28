# Contributing to denget

Thank you for considering contributing to denget!<br>
Contributions are welcomed both to [denget](https://github.com/DenisionSoft/denget) and the [main bucket](https://github.com/DenisionSoft/dgmain).<br>
Please, open your issues and commit your code in the respective repositories.

## Reporting Issues
If you find a bug or have a feature request, open a new issue on the GitHub issue tracker for [denget](https://github.com/DenisionSoft/denget/issues) or the [main bucket](https://github.com/DenisionSoft/dgmain/issues).<br>
Please include as much detail as possible, including PowerShell version, error messages, and steps to reproduce the issue.

## Contributing Code
### Set up your environment
1. Get [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows) and a recommended [Windows Terminal](https://github.com/microsoft/terminal).
2. Clone this repository: `git clone https://github.com/DenisionSoft/denget.git`

### Make a change
This project uses [Conventional Commits](https://www.conventionalcommits.org/) for commit messages.

There are two branches - a `main` branch representing the latest released version, and a `dev` branch containing the latest changes.<br>
All pull requests should be made against the `dev` branch.

1. Make sure you are on the `dev` branch: `git checkout dev`
2. Create a new branch for your changes: `git checkout -b my-feature-branch`
3. Make your changes
4. Commit your messages: `git commit -m "feat(list): add colors"`
5. Push your changes to GitHub: `git push origin my-feature-branch`
6. Open a new Pull Request on GitHub. For PR titles, follow the same Conventional Commits.

## License
By contributing to denget, you agree that your contributions will be licensed under the project's [MIT License](LICENSE).
