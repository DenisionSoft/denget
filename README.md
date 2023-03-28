![fin](https://user-images.githubusercontent.com/126210192/228084920-1a149bdf-47a9-414d-be97-33b6f5885c5a.gif)

A CLI software manager for Windows that allows you to download, update and launch programs.<br>
It supports public sources, cloud storage and BitTorrent.
## Features
denget provides a unified interface for getting all of your software, while being user-friendly and colorful.

With denget, you can:
- Install programs using a single command, even from BitTorrent
- Easily automate the installation of programs unavailable in other package managers
- Set up a private cloud source with installers and portable apps you own
- Distribute your own software

## Installation
Open your PowerShell terminal ([Windows Terminal](https://github.com/microsoft/terminal) recommended) and run:
```powershell
irm github.com/DenisionSoft/denget/releases/latest/download/install.ps1 | iex
```
For prerequisites and installation options, please see the [📥Installation](https://sumptuous-vicuna-b1e.notion.site/Installation-31e459a048634bbca6cb27845384c866) docs page.

To update denget to the latest version, run:
```powershell
denget upgrade denget
```

A [main bucket](https://github.com/DenisionSoft/dgmain) is bundled with your denget installation.

## Quick Start
To install an app, just run:
```powershell
denget install app_name
```

To see a list of installed apps, run:
```powershell
denget list
```

To learn more, visit the [🚀Starting Up](https://sumptuous-vicuna-b1e.notion.site/Starting-Up-d6b1ccba17cc43d694234143797ea5f2) docs page.

## Documentation
Documentation, usage examples and guides are [available here](https://sumptuous-vicuna-b1e.notion.site/denget-98325ea4d27b407284deccdfbf495296).

## Credit & Notices
This program was inspired by both amazing [scoop](https://github.com/ScoopInstaller/Scoop) and [winget](https://github.com/microsoft/winget-cli).<br>
It also wraps [rclone](https://github.com/rclone/rclone) and [aria2](https://github.com/aria2/aria2) for some functionality, while not using their source code. See more in [NOTICE.md](NOTICE.md).

A special thanks to Masha who made this project possible.

## License
denget and its main bucket are licensed under the [MIT license](LICENSE).

## Contributing
Please read the [contribution guidelines](CONTRIBUTING.md) for instructions on how to contribute.

If you find a bug or have a feature request, open a new issue on the [GitHub issue tracker](https://github.com/DenisionSoft/denget/issues). Please include as much detail as possible, including PowerShell version, error messages, and steps to reproduce the issue.

## Development
This project uses the [Semantic Versioning](https://semver.org/) for version numbers and [Conventional Commits](https://www.conventionalcommits.org/) for commit messages.

There are two branches - a `main` branch representing the latest released version, and a `dev` branch containing the latest changes.<br>
All pull requests should be made against the `dev` branch.

A release history with a changelog can be found on the [GitHub releases page](https://github.com/DenisionSoft/denget/releases).
