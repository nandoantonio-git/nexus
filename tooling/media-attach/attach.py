#!/usr/bin/env python3
"""Attach a local media file to GitHub and print a hosted URL.

The returned github.com/user-attachments/... URL renders as an inline image or
video player when dropped into issue / PR / comment markdown.

Usage:
    attach.py <file> [--repo owner/repo] [--content-type type]

Reads the session header from the GH_COOKIE env var (set by run.sh). Repo is
inferred from the current git remote when --repo is omitted.
"""
import os, sys, json, uuid, argparse, subprocess, mimetypes, urllib.request, urllib.error, urllib.parse

UA = "Mozilla/5.0"


def gh_json(path):
    out = subprocess.check_output(["gh", "api", path], text=True)
    return json.loads(out)


def resolve_repo(explicit):
    if explicit:
        owner_repo = explicit
    else:
        url = subprocess.check_output(["git", "remote", "get-url", "origin"], text=True).strip()
        owner_repo = url.split("github.com")[-1].lstrip(":/").removesuffix(".git")
    repo = gh_json(f"repos/{owner_repo}")
    return owner_repo, repo["id"]


def multipart(fields, filefield=None):
    b = uuid.uuid4().hex
    body = b""
    for k, v in fields.items():
        body += (f"--{b}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n{v}\r\n").encode()
    if filefield:
        fname, ctype, data = filefield
        body += (f"--{b}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"{fname}\"\r\n"
                 f"Content-Type: {ctype}\r\n\r\n").encode() + data + b"\r\n"
    body += f"--{b}--\r\n".encode()
    return body, f"multipart/form-data; boundary={b}"


def send(url, body, ctype, cookie, extra=None, method="POST"):
    h = {"User-Agent": UA, "Cookie": cookie, "Content-Type": ctype,
         "Origin": "https://github.com", "Referer": "https://github.com/",
         "Sec-Fetch-Site": "same-origin", "Sec-Fetch-Mode": "cors", "Sec-Fetch-Dest": "empty"}
    if extra:
        h.update(extra)
    return urllib.request.urlopen(urllib.request.Request(url, data=body, headers=h, method=method))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("file")
    ap.add_argument("--repo")
    ap.add_argument("--content-type")
    args = ap.parse_args()

    cookie = os.environ.get("GH_COOKIE")
    if not cookie:
        sys.exit("GH_COOKIE not set — run via run.sh")

    path = args.file
    ctype = args.content_type or mimetypes.guess_type(path)[0] or "application/octet-stream"
    name = os.path.basename(path)
    with open(path, "rb") as f:
        data = f.read()

    _, repo_id = resolve_repo(args.repo)

    body, ct = multipart({"repository_id": str(repo_id), "name": name,
                          "size": str(len(data)), "content_type": ctype})
    try:
        resp = send("https://github.com/upload/policies/assets", body, ct, cookie,
                    extra={"Accept": "application/json", "GitHub-Verified-Fetch": "true",
                           "X-Requested-With": "XMLHttpRequest"})
    except urllib.error.HTTPError as e:
        sys.exit(f"policy request failed ({e.code}) — session likely expired; re-run one-time setup")
    pol = json.loads(resp.read())

    body, ct = multipart(pol["form"], filefield=(name, ctype, data))
    extra = dict(pol.get("header") or {})
    if pol.get("same_origin"):
        extra["authenticity_token"] = pol["upload_authenticity_token"]
    send(pol["upload_url"], body, ct, cookie, extra=extra)

    body, ct = multipart({"authenticity_token": pol["asset_upload_authenticity_token"]})
    send(urllib.parse.urljoin("https://github.com/", pol["asset_upload_url"]), body, ct, cookie,
         extra={"Accept": "application/json", "X-Requested-With": "XMLHttpRequest"}, method="PUT")

    print(pol["asset"]["href"])


if __name__ == "__main__":
    main()
