# Wordpress files

## realtimedata.{css,js,html}

Files required to render the realtime data section in our marketing website (metrist.io)

The JavaScript file is stored under `s3://canary-public-assets/dist/js/` so you'll have to run the following
if the file is modified

```sh
aws s3 cp realtimedata.js s3://canary-public-assets/dist/js/
```

The CSS needs to be copied manually to kinsta. Note that the `selector` CSS selector is a special selector
only available in Kinsta to refer to the container element

The HTML file is there for testing. You can run the following to serve the static files in http://localhost:9000

```sh
python3 -m http.server 9000
```

