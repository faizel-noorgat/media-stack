[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/linuxshots)

# media-stack

A stack of self-hosted media managers and streamer along with VPN. 

Stack include VPN, Radarr, Sonarr, Prowlarr, qBittorrent, Jellyseerr and Jellyfin.

## Requirements

- Docker version 24.0.5 and above
- Docker compose version v2.20.2 and above
- It may also work on some of lower versions, but its not tested.

## Install media stack


> **WARNING for armv7 users:** Breaking changes in Jellyseerr version 2.0.x. Jellyseerr 2.0.x have dropped the support for armv7 container image. Support for arm64 is still present. If you are using media stack on armv7, You may need to use Jellyseerr v1.9.x until support is back for armv7.
> Details here: 
>
> https://github.com/Fallenbagel/jellyseerr/releases/tag/v2.0.0
>
> https://github.com/Fallenbagel/jellyseerr/releases/tag/v2.0.1
>


There are two ways this stack can be deployed.

1. With a VPN (Recommended)
2. Without a VPN

> **NOTE:** If you are installing this stack without VPN, You must use `no-vpn` profile. This has been made mandatory to avoid accidental/unknowingly deployment of media-stack without VPN.
> Running `docker compose` command without a profile will not deploy anything.
>
> Check installation steps below.
>


Before we deploy the stack, We must create docker network first

```bash
docker network create --subnet 172.20.0.0/16 mynetwork
# Update CIDR range as per your IP range availability
```

**Deploy the stack with VPN**

If VPN is enabled, qBittorrent and Prowlarr will be put behind VPN.

By default, NordVPN is used in `docker-compose.yml` file. This can be updated to use ExpressVPN, SurfShark, ProtonVPN, Custom OpenVPN or Wireguard VPN. It uses OpenVPN type for all the providers. 

Check respective document of your VPN provider to generate OpenVPN username and password.
Follow https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers to configure gluetun for your VPN provider.

By default, VPN is disabled in `docker-compose.yml`. We just need to comment and uncomment few lines in `docker-compose.yml` file to enable and use VPN. Go through the comment messages in `docker-compose.yml` file to update them accordingly. Its very well guided in the compose file itself.

Update the `docker-compose.yml` file as guided per instructions in commit messsages in same file and follow below commands to deploy the stack.

To deploy the stack with VPN (with nordvpn):

```bash
VPN_SERVICE_PROVIDER=nordvpn OPENVPN_USER=openvpn-username OPENVPN_PASSWORD=openvpn-password SERVER_COUNTRIES=Switzerland RADARR_STATIC_CONTAINER_IP=radarr-container-static-ip SONARR_STATIC_CONTAINER_IP=sonarr-container-static-ip docker compose --profile vpn up -d

# docker compose -f docker-compose-nginx.yml up -d # OPTIONAL to use Nginx as reverse proxy
```

*Static container IP address is needed when prowlarr is behind VPN. This is because in this case Prowlar can reach out to Radarr and Sonarr only with their container IP addresses. With static IPs of both, We can configure them in Prowlarr without need of changing it everytime container restarts.*

*This is set using RADARR_STATIC_CONTAINER_IP and SONARR_STATIC_CONTAINER_IP variables.*

**Deploy the stack without VPN**

To deploy the stack without VPN (highly discouraged), Run below command.

```bash
docker compose --profile no-vpn up -d
# docker compose -f docker-compose-nginx.yml up -d # OPTIONAL to use Nginx as reverse proxy
```

## Configure qBittorrent

- Open qBitTorrent at http://localhost:5080. Default username is `admin`. Temporary password can be collected from container log `docker logs qbittorrent`
- Go to Tools --> Options --> WebUI --> Change password
- Run below commands on the server

```bash
docker exec -it qbittorrent bash # Get inside qBittorrent container

# Above command will get you inside qBittorrent interactive terminal, Run below command in qbt terminal
mkdir /downloads/movies /downloads/tvshows
chown 1000:1000 /downloads/movies /downloads/tvshows
```

## Configure Radarr

- Open Radarr at http://localhost:7878
- Settings --> Media Management --> Check mark "Movies deleted from disk are automatically unmonitored in Radarr" under File management section --> Save
- Settings --> Media Management --> Scroll to bottom --> Add Root Folder --> Browse to /downloads/movies --> OK
- Settings --> Download clients --> qBittorrent --> Add Host (qbittorrent) and port (5080) --> Username and password --> Test --> Save **Note: If VPN is enabled, then qbittorrent is reachable on vpn's service name. In this case use `vpn` in Host field.**
- Settings --> General --> Enable advance setting --> Select Authentication and add username and password
- Indexer will get automatically added during configuration of Prowlarr. See 'Configure Prowlarr' section.

Sonarr can also be configured in similar way.

**Add a movie** (After Prowlarr is configured)

- Movies --> Search for a movie --> Add Root folder (/downloads/movies) --> Quality profile --> Add movie
- All queued movies download can be checked here, Activities --> Queue 
- Go to qBittorrent (http://localhost:5080) and see if movie is getting downloaded (After movie is queued. This depends on availability of movie in indexers configured in Prowlarr.)

## Configure Jellyfin

- Open Jellyfin at http://localhost:8096
- When you access the jellyfin for first time using browser, A guided configuration will guide you to configure jellyfin. Just follow the guide.
- Add media library folder and choose /data/movies/

## Configure Jellyseerr

- Open Jellyfin at http://localhost:5055
- When you access the jellyseerr for first time using browser, A guided configuration will guide you to configure jellyseerr. Just follow the guide and provide the required details about sonarr and Radarr.
- Follow the Overseerr document (Jellyseerr is fork of overseerr) for detailed setup - https://docs.overseerr.dev/ 

## Configure Prowlarr

- Open Prowlarr at http://localhost:9696
- Settings --> General --> Authentications --> Select Authentication and add username and password
- Add Indexers, Indexers --> Add Indexer --> Search for indexer --> Choose base URL --> Test and Save
- Add application, Settings --> Apps --> Add application --> Choose Radarr --> Prowlarr server (http://prowlarr:9696) --> Radarr server (http://radarr:7878) --> API Key --> Test and Save
- Add application, Settings --> Apps --> Add application --> Choose Sonarr --> Prowlarr server (http://prowlarr:9696) --> Sonarr server (http://sonarr:8989) --> API Key --> Test and Save
- This will add indexers in respective apps automatically.

**Note: If VPN is enabled, then Prowlarr will not be able to reach radarr and sonarr with localhost or container service name. In that case use static IP for sonarr and radarr in radarr/sonarr server field (for e.g. http://172.19.0.5:8989). Prowlar will also be not reachable with its container/service name. Use `http://vpn:9696` instead in prowlar server field.**

## Configure Nginx

- Get inside Nginx container
- `cd /etc/nginx/conf.d`
- Add proxies for all tools.

`docker cp nginx.conf nginx:/etc/nginx/conf.d/default.conf && docker exec -it nginx nginx -s reload`
- Close ports of other tools in firewall/security groups except port 80 and 443.


## Apply SSL in Nginx

- Open port 80 and 443.
- Get inside Nginx container and install certbot and certbot-nginx `apk add certbot certbot-nginx`
- Add URL in server block. e.g. `server_name  localhost mediastack.example.com;` in /etc/nginx/conf.d/default.conf
- Run `certbot --nginx` and provide details asked.

## Radarr Nginx reverse proxy

- Settings --> General --> URL Base --> Add base (/radarr)
- Add below proxy in nginx configuration

```
location /radarr {
    proxy_pass http://radarr:7878;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $http_connection;
  }
```

- Restart containers.

## Sonarr Nginx reverse proxy

- Settings --> General --> URL Base --> Add base (/sonarr)
- Add below proxy in nginx configuration

```
location /sonarr {
    proxy_pass http://sonarr:8989;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $http_connection;
  }
```

## Prowlarr Nginx reverse proxy

- Settings --> General --> URL Base --> Add base (/prowlarr)
- Add below proxy in nginx configuration

This may need to change configurations in indexers and base in URL.

```
location /prowlarr {
    proxy_pass http://prowlarr:9696; # Comment this line if VPN is enabled.
    # proxy_pass http://vpn:9696; # Uncomment this line if VPN is enabled.
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $http_connection;
  }
```

- Restart containers.

**Note: If VPN is enabled, then Prowlarr is reachable on vpn's service name**

## qBittorrent Nginx proxy

```
location /qbt/ {
    proxy_pass         http://qbittorrent:5080/; # Comment this line if VPN is enabled.
    # proxy_pass         http://vpn:5080/; # Uncomment this line if VPN is enabled.
    proxy_http_version 1.1;

    proxy_set_header   Host               http://qbittorrent:5080; # Comment this line if VPN is enabled.
    # proxy_set_header   Host               http://vpn:5080; # Uncomment this line if VPN is enabled.
    proxy_set_header   X-Forwarded-Host   $http_host;
    proxy_set_header   X-Forwarded-For    $remote_addr;
    proxy_cookie_path  /                  "/; Secure";
}
```

**Note: If VPN is enabled, then qbittorrent is reachable on vpn's service name**

## Jellyfin Nginx proxy

- Add base URL, Admin Dashboard -> Networking -> Base URL (/jellyfin)
- Add below config in Ngix config

```
 location /jellyfin {
        return 302 $scheme://$host/jellyfin/;
    }

    location /jellyfin/ {

        proxy_pass http://jellyfin:8096/jellyfin/;

        proxy_pass_request_headers on;

        proxy_set_header Host $host;

        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $http_host;

        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $http_connection;

        # Disable buffering when the nginx proxy gets very resource heavy upon streaming
        proxy_buffering off;
    }
```

## Jellyseerr Nginx proxy

**Currently Jellyseerr/Overseerr doesnot officially support the subfolder/path reverse proxy. They have a workaround documented here without an official support. Find it [here](https://docs.overseerr.dev/extending-overseerr/reverse-proxy)**

```
location / {
        proxy_pass http://127.0.0.1:5055;

        proxy_set_header Referer $http_referer;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Real-Port $remote_port;
        proxy_set_header X-Forwarded-Host $host:$remote_port;
        proxy_set_header X-Forwarded-Server $host;
        proxy_set_header X-Forwarded-Port $remote_port;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Ssl on;
    }
```

- Restart containers

Got it! You're using **NFS mounts from `192.168.1.12`** with the correct paths. I'll update the script accordingly.

---

### **✅ Step 1: Corrected Setup Script (`setup.sh`)**
This script will:
- Ensure the **user has UID 1000**.
- **Create necessary mount points**.
- **Update `/etc/fstab`** with the correct NFS mounts.
- **Set correct permissions**.

```bash
#!/bin/bash

# Set variables
USER_NAME="your-username"  # Change this if needed
USER_ID=1000
GROUP_ID=1000

MOUNT_POINTS=(
    "/mnt/downloads"
    "/mnt/movies"
    "/mnt/series"
)

NFS_SERVER="192.168.1.12"  # Your actual NFS server IP
NFS_SHARES=(
    "/mnt/Loci201DataLake/Media/Downloads"
    "/mnt/Loci201DataLake/Media/Movies"
    "/mnt/Loci201DataLake/Media/Series"
)

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

echo "🔧 Ensuring user $USER_NAME has UID 1000..."

# Check if user exists, otherwise create it
if id "$USER_NAME" &>/dev/null; then
    echo "✅ User $USER_NAME already exists."
else
    echo "⚠️ User $USER_NAME not found. Creating user..."
    useradd -u $USER_ID -g $GROUP_ID -m -s /bin/bash $USER_NAME
    echo "✅ User $USER_NAME created with UID $USER_ID."
fi

# Ensure home folder permissions are correct
chown -R $USER_NAME:$USER_NAME /home/$USER_NAME

echo "🔧 Creating mount directories..."
for MOUNT in "${MOUNT_POINTS[@]}"; do
    if [[ ! -d "$MOUNT" ]]; then
        mkdir -p "$MOUNT"
        echo "✅ Created $MOUNT"
    else
        echo "✅ $MOUNT already exists."
    fi
done

echo "🔧 Updating /etc/fstab for persistent mounts..."

# Backup fstab before modifying
cp /etc/fstab /etc/fstab.backup-$(date +%F-%T)

# Add NFS mounts to fstab if not already present
for i in "${!MOUNT_POINTS[@]}"; do
    if ! grep -qs "${MOUNT_POINTS[$i]}" /etc/fstab; then
        echo "$NFS_SERVER:${NFS_SHARES[$i]} ${MOUNT_POINTS[$i]} nfs defaults,_netdev 0 0" >> /etc/fstab
        echo "✅ Added ${MOUNT_POINTS[$i]} to fstab."
    else
        echo "✅ ${MOUNT_POINTS[$i]} already in fstab."
    fi
done

echo "🔧 Mounting all filesystems..."
mount -a

echo "🔧 Setting correct permissions..."
chown -R $USER_NAME:$USER_NAME /mnt/*
chmod -R 775 /mnt/*

echo "✅ All mounts and permissions are set! Reboot recommended."
```

---

### **✅ Step 2: How to Use the Script**
1️⃣ Copy and save this script as `setup.sh` on your new VM:
```bash
nano setup.sh
```
(Paste the script inside, then save with `CTRL+X`, `Y`, `Enter`.)  

2️⃣ **Make the script executable**:
```bash
chmod +x setup.sh
```

3️⃣ **Run the script as root**:
```bash
sudo ./setup.sh
```

4️⃣ **Verify the mounts**:
```bash
df -h
```
You should see:
```
192.168.1.12:/mnt/Loci201DataLake/Media/Downloads  →  /mnt/downloads
192.168.1.12:/mnt/Loci201DataLake/Media/Movies     →  /mnt/movies
192.168.1.12:/mnt/Loci201DataLake/Media/Series     →  /mnt/series
```

---

### **🔥 Next Steps**
After verifying that **the mounts and permissions are working**, we can proceed with:
✅ Installing Docker  
✅ Deploying your `docker-compose.yml`  

Let me know when you're ready! 🚀
