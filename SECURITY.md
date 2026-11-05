# Security reporting

Report vulnerabilities privately using **Report a vulnerability** on this
repository's [Security tab](https://github.com/alexcatdad/menubar-kit/security).

Include the affected MenubarKit version (tag), the macOS version, which API is
involved and a minimal synthetic reproduction. Do not include real credentials,
private app code or personal data.

Notification and permission behaviour is security-relevant: report any path
that posts a notification while the user's toggle is off, requests permission
outside a user action, or posts without the calling app's bundle attribution.

Only the latest tag receives fixes. Apps pin exact tags, so a fix ships as a
new tag that each app adopts.
