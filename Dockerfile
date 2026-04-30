FROM debian@sha256:f9c6a2fd2ddbc23e336b6257a5245e31f996953ef06cd13a59fa0a1df2d5c252

RUN apt-get update \
 && apt-get install -y --no-install-recommends nextcloud-desktop-cmd \
 && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

COPY syncexclude.lst /config/syncexclude.lst
COPY unsyncedfolders.lst /config/unsyncedfolders.lst
COPY syncedfolders.lst /config/syncedfolders.lst

ENTRYPOINT ["/entrypoint.sh"]
