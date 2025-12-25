<%@ Page Language="C#" %>
<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="System.Web" %>

<script runat="server">
    // Static lock object to prevent file access errors when multiple users visit at once
    private static readonly object _counterLock = new object();
    
    string rootPath = "";
    string currentRelativePath = "";
    int visitorCount = 0;
    string serverBaseUrl = ""; 

    protected void Page_Load(object sender, EventArgs e)
    {
        // 0. Get Server Base URL
        serverBaseUrl = Request.Url.Scheme + "://" + Request.Url.Authority;

        // 1. Path Logic & Security Check
        rootPath = Server.MapPath("~/");
        string reqPath = Request.QueryString["path"];

        if (string.IsNullOrEmpty(reqPath))
        {
            currentRelativePath = "";
        }
        else
        {
            // Basic sanitation
            reqPath = reqPath.Replace("..", "").Replace("//", "/").TrimStart('/');
            currentRelativePath = reqPath;

            // Security: Ensure the requested path is actually inside the root folder
            try {
                string checkPath = Path.GetFullPath(Path.Combine(rootPath, reqPath));
                if (!checkPath.StartsWith(rootPath)) {
                    currentRelativePath = ""; // Reset to root if malicious path detected
                }
            } catch {
                currentRelativePath = "";
            }
        }

        // 2. Visitor Counter (Thread Safe)
        string counterFile = Server.MapPath("~/counter.txt");
        
        if (Session["HasVisited"] == null)
        {
            lock (_counterLock) // Prevents crash if 2 users visit same time
            {
                try {
                    if (File.Exists(counterFile)) {
                        string content = File.ReadAllText(counterFile);
                        int.TryParse(content, out visitorCount);
                    }
                    visitorCount++;
                    File.WriteAllText(counterFile, visitorCount.ToString());
                    Session["HasVisited"] = "true"; 
                }
                catch { visitorCount = 0; }
            }
        }
        else 
        {
            try {
                if (File.Exists(counterFile)) {
                    string content = File.ReadAllText(counterFile);
                    int.TryParse(content, out visitorCount);
                }
            } catch { }
        }
    }

    string GetIconClass(string ext)
    {
        ext = ext.ToLower();
        if (ext == ".png" || ext == ".jpg" || ext == ".jpeg" || ext == ".gif") return "fa-solid fa-file-image text-primary";
        if (ext == ".pdf") return "fa-solid fa-file-pdf text-danger";
        if (ext == ".zip" || ext == ".rar" || ext == ".7z") return "fa-solid fa-file-zipper text-warning";
        if (ext == ".mp4" || ext == ".mkv" || ext == ".avi" || ext == ".mov" || ext == ".webm" || ext == ".ts") return "fa-solid fa-file-video text-success";
        if (ext == ".mp3" || ext == ".wav") return "fa-solid fa-file-audio text-info";
        if (ext == ".txt" || ext == ".log" || ext == ".xml") return "fa-solid fa-file-lines text-secondary";
        if (ext == ".html" || ext == ".css" || ext == ".js" || ext == ".json" || ext == ".php") return "fa-solid fa-file-code text-dark";
        if (ext == ".exe" || ext == ".msi" || ext == ".iso") return "fa-brands fa-windows text-primary";
        if (ext == ".apk") return "fa-brands fa-android text-success";
        return "fa-solid fa-file text-muted";
    }

    bool IsVideoFile(string ext)
    {
        ext = ext.ToLower();
        return (ext == ".mp4" || ext == ".mkv" || ext == ".avi" || ext == ".mov" || ext == ".webm" || ext == ".ts");
    }

    string FormatSize(long bytes)
    {
        if (bytes >= 1073741824) return (bytes / 1073741824.0).ToString("0.00") + " GB";
        if (bytes >= 1048576) return (bytes / 1048576.0).ToString("0.00") + " MB";
        if (bytes >= 1024) return (bytes / 1024.0).ToString("0.00") + " KB";
        return bytes + " B";
    }
</script>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sarker Net File Server</title>
    <link rel="icon" href="assets/logos/logo.png">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" rel="stylesheet">
    
    <style>
        body { background-color: #f0f2f5; font-family: 'Segoe UI', sans-serif; padding-top: 45px; }
        
        /* Marquee */
        .news-ticker {
            position: fixed; top: 0; left: 0; width: 100%; z-index: 1050;
            background: #2d3436; color: #ffffff; padding: 8px 0;
            font-size: 14px; border-bottom: 2px solid #0984e3; letter-spacing: 0.5px;
        }

        .main-card { border: none; border-radius: 12px; box-shadow: 0 5px 20px rgba(0,0,0,0.05); overflow: hidden; }
        
        /* Search */
        .search-icon { position: absolute; top: 13px; left: 15px; color: #6c757d; }
        .form-control-lg { padding-left: 45px; border-radius: 8px; font-size: 1rem; border: 1px solid #ced4da; }
        .form-control-lg:focus { box-shadow: 0 0 0 4px rgba(13, 110, 253, 0.15); border-color: #86b7fe; }
        
        /* Table Styling */
        .table-hover tbody tr:hover { background-color: #f8f9fa; }
        .icon-col { width: 50px; text-align: center; font-size: 1.8rem; }
        
        a.file-link { text-decoration: none; color: #2d3436; font-weight: 600; display: block; word-break: break-word; font-size: 1rem; }
        a.file-link:hover { color: #0984e3; }
        
        /* Buttons */
        .app-btn { font-weight: 600; padding: 10px 20px; border-radius: 8px; text-decoration: none; transition: 0.3s; display: inline-flex; align-items: center; white-space: nowrap; font-size: 0.9rem; border: none; box-shadow: 0 2px 5px rgba(0,0,0,0.1); cursor: pointer; }
        .app-btn:hover { transform: translateY(-2px); box-shadow: 0 5px 15px rgba(0,0,0,0.2); }
        
        .btn-live { background-color: #e74c3c; color: white; } 
        .btn-emby { background-color: #27ae60; color: white; } 
        .btn-ftp { background-color: #6c5ce7; color: white; }
        .btn-telegram { background-color: #0088cc; color: white; }
        .btn-help { background-color: #95a5a6; color: white; }
        
        /* Server Menu Buttons & Modal */
        .btn-server { background: #2d3436; color: white; border: 1px solid #4a4a4a; }
        .btn-services { background: #636e72; color: white; border: 1px solid #4a4a4a; }

        .server-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 15px; }
        .service-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 15px; }

        /* Generic Item Style */
        .menu-item-box { display: flex; justify-content: space-between; align-items: center; padding: 15px 15px; background-color: #f1f2f6; border-radius: 8px; text-decoration: none; color: #2f3542; font-weight: 600; font-size: 0.9rem; transition: all 0.2s ease; border-left: 4px solid transparent; }
        .menu-item-box:hover { background-color: #e3f2fd; color: #0984e3; box-shadow: 0 4px 10px rgba(0,0,0,0.08); transform: translateX(3px); }
        
        /* Specific Border Colors on Hover */
        .hover-border-blue:hover { border-left-color: #0984e3; }
        .hover-border-red:hover { border-left-color: #e74c3c; color: #e74c3c; background-color: #ffeaa7; }
        .hover-border-green:hover { border-left-color: #27ae60; color: #27ae60; background-color: #dff9fb; }
        .hover-border-purple:hover { border-left-color: #6c5ce7; color: #6c5ce7; background-color: #dfe6e9; }
        .hover-border-teal:hover { border-left-color: #00cec9; color: #00cec9; background-color: #dff9fb; }

        .server-badge { background-color: #dfe4ea; color: #57606f; font-size: 0.75rem; padding: 3px 8px; border-radius: 4px; }
        .menu-item-box:hover .server-badge { background-color: #0984e3; color: white; }
        
        .modal-header-custom { background-color: #f8f9fa; border-bottom: 1px solid #eee; }
        .menu-header-custom { color: #a4b0be; font-weight: 800; text-transform: uppercase; font-size: 0.75rem; letter-spacing: 1px; margin-bottom: 10px; margin-top: 5px; }

        /* Player Dropdown */
        .player-menu { min-width: 230px; padding: 10px; border: none; box-shadow: 0 5px 25px rgba(0,0,0,0.15); border-radius: 10px; }
        .player-item { display: flex; align-items: center; padding: 10px 15px; border-radius: 6px; color: #333; font-weight: 500; text-decoration: none; transition: 0.2s; font-size: 0.95rem; }
        .player-item:hover { background-color: #f1f2f6; color: #000; }
        .player-icon { width: 25px; text-align: center; margin-right: 12px; font-size: 1.1rem; }
        .color-pot { color: #9b59b6; }
        .color-vlc { color: #e67e22 !important; }
        .color-mx { color: #3498db; }
        .color-mxpro { color: #2980b9; }

        /* Toast */
        #toast { visibility: hidden; min-width: 250px; background-color: #333; color: #fff; text-align: center; border-radius: 50px; padding: 12px; position: fixed; z-index: 1100; left: 50%; bottom: 30px; transform: translateX(-50%); font-size: 15px; box-shadow: 0 4px 15px rgba(0,0,0,0.3); }
        #toast.show { visibility: visible; -webkit-animation: fadein 0.5s, fadeout 0.5s 2.5s; animation: fadein 0.5s, fadeout 0.5s 2.5s; }
        @-webkit-keyframes fadein { from {bottom: 0; opacity: 0;} to {bottom: 30px; opacity: 1;} }
        @keyframes fadein { from {bottom: 0; opacity: 0;} to {bottom: 30px; opacity: 1;} }
        @-webkit-keyframes fadeout { from {bottom: 30px; opacity: 1;} to {bottom: 0; opacity: 0;} }
        @keyframes fadeout { from {bottom: 30px; opacity: 1;} to {bottom: 0; opacity: 0;} }
        
        .visitor-counter { background: #fff; border: 1px solid #e9ecef; color: #495057; padding: 5px 20px; border-radius: 50px; font-size: 0.9rem; margin-top: 15px; display: inline-block; box-shadow: 0 2px 10px rgba(0,0,0,0.05); }
        .live-clock { font-size: 0.9rem; color: #636e72; font-weight: 500; }

        /* Bootstrap Display Utilities Replacement */
        .pc-only { display: block; }
        .mobile-only { display: none; }

        @media (max-width: 768px) {
            .pc-only { display: none !important; }
            .mobile-only { display: block !important; }
            .header-stack { flex-direction: column; text-align: center; }
            .header-stack > div { justify-content: center; width: 100%; margin-top: 10px; }
            .app-btn { width: 100%; justify-content: center; margin-bottom: 5px; }
            .server-grid, .service-grid { grid-template-columns: 1fr; gap: 10px; }
            .table-responsive { border: 0; }
            body { padding-top: 50px; }
        }
    </style>
</head>
<body>

    <div id="toast"><i class="fa-solid fa-check-circle me-2"></i> Link Copied!</div>

    <div class="news-ticker">
        <marquee scrollamount="8" onmouseover="this.stop();" onmouseout="this.start();">
            Sarker Net – Your reliable, modern & customer-friendly internet partner | Affordable tech-rich connection, 24/7 Support | bKash: 01329609346 or Nagad Bill Pay: Sarker Net
        </marquee>
    </div>

    <div class="container py-4 mt-4">
        <div class="row justify-content-center">
            <div class="col-lg-10">
                
                <div class="d-flex justify-content-between align-items-center mb-4 flex-wrap gap-3 header-stack">
                    <div>
                        <h3 class="fw-bold mb-0 text-dark" style="letter-spacing: -0.5px;">
                            <i class="fa-solid fa-server text-primary me-2"></i>Sarker Net <span class="text-muted fw-normal">Files</span>
                        </h3>
                        <div id="clock" class="text-muted small mt-1 fw-bold">Loading time...</div>
                    </div>
                    
                    <div class="d-flex gap-2 flex-wrap">
                        
                        <button class="btn btn-server app-btn" type="button" data-bs-toggle="modal" data-bs-target="#storageNodesModal">
                            <i class="fa-solid fa-hard-drive me-2"></i> Storage Nodes
                        </button>

                        <button class="btn btn-services app-btn" type="button" data-bs-toggle="modal" data-bs-target="#mediaServicesModal">
                            <i class="fa-solid fa-layer-group me-2"></i> Media & Services
                        </button>

                        <a href="https://t.me/+59KXZDQ-K_s2YzRl" target="_blank" class="app-btn btn-telegram"><i class="fa-brands fa-telegram me-2"></i> Request Group</a>

                        <button class="btn btn-help app-btn" type="button" data-bs-toggle="modal" data-bs-target="#helpModal">
                            <i class="fa-solid fa-circle-question me-2"></i> Help
                        </button>
                    </div>
                </div>


                <div class="card main-card p-4 bg-white">
                    <div class="position-relative mb-4">
                        <i class="fa-solid fa-magnifying-glass search-icon"></i>
                        <input type="text" id="fileSearch" class="form-control form-control-lg" placeholder="Type to search files..." onkeyup="filterTable()">
                    </div>

                    <nav aria-label="breadcrumb">
                        <ol class="breadcrumb mb-3">
                            <li class="breadcrumb-item"><a href="Default.aspx" class="text-decoration-none">Home</a></li>
                            <% if (!string.IsNullOrEmpty(currentRelativePath)) { %>
                                <li class="breadcrumb-item active"><%= currentRelativePath %></li>
                            <% } %>
                        </ol>
                    </nav>

                    <div class="table-responsive">
                        <table class="table align-middle" id="fileTable">
                            <thead class="table-light">
                                <tr>
                                    <th class="icon-col"></th>
                                    <th>Name</th>
                                    <th class="d-none d-md-table-cell" style="width: 15%">Size</th>
                                    <th class="d-none d-md-table-cell" style="width: 20%">Date</th>
                                    <th style="width: 25%" class="text-end">Action</th>
                                </tr>
                            </thead>
                            <tbody>
                                <% 
                                    try {
                                        string fullPath = Path.Combine(rootPath, currentRelativePath);
                                        DirectoryInfo di = new DirectoryInfo(fullPath);

                                        if (!string.IsNullOrEmpty(currentRelativePath)) {
                                            string parent = currentRelativePath.Contains("/") ? currentRelativePath.Substring(0, currentRelativePath.LastIndexOf('/')) : "";
                                %>
                                    <tr class="folder-row">
                                        <td class="icon-col"><i class="fa-solid fa-folder-open text-warning"></i></td>
                                        <td colspan="4"><a href="?path=<%= parent %>" class="file-link text-muted">... (Go Up)</a></td>
                                    </tr>
                                <%      }

                                        foreach (DirectoryInfo d in di.GetDirectories()) {
                                            if (d.Name.StartsWith(".") || d.Attributes.HasFlag(FileAttributes.Hidden)) continue;
                                            string newPath = string.IsNullOrEmpty(currentRelativePath) ? d.Name : currentRelativePath + "/" + d.Name;
                                %>
                                    <tr class="item-row">
                                        <td class="icon-col"><i class="fa-solid fa-folder text-warning"></i></td>
                                        <td class="text-break"><a href="?path=<%= newPath %>" class="file-link"><%= d.Name %></a></td>
                                        <td class="text-muted small d-none d-md-table-cell">-</td>
                                        <td class="text-muted small d-none d-md-table-cell"><%= d.LastWriteTime.ToString("yyyy-MM-dd") %></td>
                                        <td class="text-end"><a href="?path=<%= newPath %>" class="btn btn-sm btn-light border"><i class="fa-solid fa-arrow-right"></i></a></td>
                                    </tr>
                                <%      } 

                                        foreach (FileInfo f in di.GetFiles()) {
                                            if (f.Name.Equals("Default.aspx", StringComparison.OrdinalIgnoreCase) || f.Name.Equals("web.config", StringComparison.OrdinalIgnoreCase) || f.Name.Equals("counter.txt", StringComparison.OrdinalIgnoreCase)) continue;
                                            
                                            string link = string.IsNullOrEmpty(currentRelativePath) ? f.Name : currentRelativePath + "/" + f.Name;
                                            bool isVideo = IsVideoFile(f.Extension);
                                            string fullUrl = serverBaseUrl + Request.ApplicationPath.TrimEnd('/') + "/" + link;
                                %>
                                    <tr class="item-row">
                                        <td class="icon-col"><i class="<%= GetIconClass(f.Extension) %>"></i></td>
                                        <td class="text-break"><a href="<%= link %>" download class="file-link"><%= f.Name %></a></td>
                                        <td class="text-muted small d-none d-md-table-cell"><%= FormatSize(f.Length) %></td>
                                        <td class="text-muted small d-none d-md-table-cell"><%= f.LastWriteTime.ToString("yyyy-MM-dd") %></td>
                                        <td class="text-end" style="white-space: nowrap;">
                                            <% if (isVideo) { %>
                                                <div class="dropdown d-inline-block">
                                                    <button class="btn btn-sm btn-success dropdown-toggle fw-bold" type="button" data-bs-toggle="dropdown" aria-expanded="false">
                                                        <i class="fa-solid fa-play me-1"></i> Stream
                                                    </button>
                                                    <ul class="dropdown-menu dropdown-menu-end player-menu">
                                                        <li><a class="player-item" href="<%= link %>" target="_blank"><i class="fa-solid fa-globe player-icon"></i> Web Browser</a></li>
                                                        <li><hr class="dropdown-divider"></li>
                                                        
                                                        <li class="pc-only"><a class="player-item color-pot" href="potplayer://<%= fullUrl %>"><i class="fa-solid fa-circle-play player-icon"></i> PotPlayer</a></li>
                                                        <li class="pc-only"><a class="player-item color-vlc" href="vlc://<%= fullUrl %>"><i class="fa-solid fa-circle-play player-icon"></i> VLC Player</a></li>
                                                        <li class="pc-only"><a class="player-item color-mx" href="intent:<%= fullUrl %>#Intent;package=com.mxtech.videoplayer.ad;type=video/*;end"><i class="fa-solid fa-play player-icon"></i> MX Player</a></li>
                                                        <li class="pc-only"><a class="player-item color-mxpro" href="intent:<%= fullUrl %>#Intent;package=com.mxtech.videoplayer.pro;type=video/*;end"><i class="fa-solid fa-star player-icon"></i> MX Player Pro</a></li>
                                                        
                                                        <li class="mobile-only"><a class="player-item color-mx" href="intent:<%= fullUrl %>#Intent;package=com.mxtech.videoplayer.ad;type=video/*;end"><i class="fa-solid fa-play player-icon"></i> MX Player</a></li>
                                                        <li class="mobile-only"><a class="player-item color-mxpro" href="intent:<%= fullUrl %>#Intent;package=com.mxtech.videoplayer.pro;type=video/*;end"><i class="fa-solid fa-star player-icon"></i> MX Player Pro</a></li>
                                                    </ul>
                                                </div>
                                            <% } %>
                                            
                                                <div class="btn-group ms-1" role="group">
                                                <a href="<%= link %>" download title="Download Now" class="btn btn-sm btn-primary">
                                                <i class="fa-solid fa-cloud-arrow-down"></i> <span class="d-none d-md-inline">Download Now</span>
                                                </a>
                                                </div>
                                                
                                                <div class="btn-group ms-1" role="group">
                                                <button onclick="copyLink('<%= fullUrl %>')" title="Copy URL" class="btn btn-sm btn-secondary">
                                                    <i class="fa-solid fa-copy"></i>
                                                </button>
                                            </div>
                                        </td>
                                    </tr>
                                <%      } 
                                    } catch { %>
                                    <tr><td colspan="5" class="text-danger">Error loading files.</td></tr>
                                <% } %>
                            </tbody>
                        </table>
                    </div>

                    <div id="noResults" class="text-center py-5 d-none">
                        <p class="text-muted fs-5">No files found matching "<span id="searchText"></span>"</p>
                    </div>
                </div>

                <div class="text-center mt-3">
                    <div class="visitor-counter">
                        <i class="fa-solid fa-eye me-2 text-primary"></i> Total Visits: <strong><%= visitorCount %></strong>
                    </div>
                    <div class="text-muted small mt-2 fw-bold">
                        Sarker Net File Server
                    </div>
                </div>

            </div>
        </div>
    </div>

    <div class="modal fade" id="storageNodesModal" tabindex="-1" aria-labelledby="storageNodesModalLabel" aria-hidden="true">
      <div class="modal-dialog modal-lg modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header modal-header-custom">
            <h5 class="modal-title fw-bold" id="storageNodesModalLabel"><i class="fa-solid fa-server text-primary me-2"></i>Available Storage Nodes</h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
          </div>
          <div class="modal-body p-4">
            <div class="server-grid">
                <div>
                    <h6 class="menu-header-custom">Primary Disks</h6>
                    <a class="menu-item-box hover-border-blue" href="http://100.100.100.6:8080" target="_blank"><span><i class="fa-solid fa-hdd me-2 text-muted"></i>Port 8080</span> <span class="server-badge">DISK E</span></a>
                    <a class="menu-item-box mt-2 hover-border-blue" href="http://100.100.100.6:8081" target="_blank"><span><i class="fa-solid fa-hdd me-2 text-muted"></i>Port 8081</span> <span class="server-badge">DISK E</span></a>
                    <a class="menu-item-box mt-2 hover-border-blue" href="http://100.100.100.6:8082" target="_blank"><span><i class="fa-solid fa-hdd me-2 text-muted"></i>Port 8082</span> <span class="server-badge">DISK F</span></a>
                    <a class="menu-item-box mt-2 hover-border-blue" href="http://100.100.100.6:8083" target="_blank"><span><i class="fa-solid fa-hdd me-2 text-muted"></i>Port 8083</span> <span class="server-badge">DISK F</span></a>
                    <a class="menu-item-box mt-2 hover-border-blue" href="http://100.100.100.6:8084" target="_blank"><span><i class="fa-solid fa-hdd me-2 text-muted"></i>Port 8084</span> <span class="server-badge">DISK G</span></a>
                    <a class="menu-item-box mt-2 hover-border-blue" href="http://100.100.100.6:8085" target="_blank"><span><i class="fa-solid fa-hdd me-2 text-muted"></i>Port 8085</span> <span class="server-badge">DISK G</span></a>
                    <a class="menu-item-box mt-2 hover-border-blue" href="http://100.100.100.6:8086" target="_blank"><span><i class="fa-solid fa-hdd me-2 text-muted"></i>Port 8086</span> <span class="server-badge">DISK H</span></a>
                    <a class="menu-item-box mt-2 hover-border-blue" href="http://100.100.100.6:8087" target="_blank"><span><i class="fa-solid fa-hdd me-2 text-muted"></i>Port 8087</span> <span class="server-badge">DISK H</span></a>
                </div>
                <div>
                    <h6 class="menu-header-custom">Secondary Disks</h6>
                    <a class="menu-item-box hover-border-blue" href="http://100.100.100.6:8088" target="_blank"><span><i class="fa-solid fa-hdd me-2 text-muted"></i>Port 8088</span> <span class="server-badge">DISK I</span></a>
                    <a class="menu-item-box mt-2 hover-border-blue" href="http://100.100.100.6:8089" target="_blank"><span><i class="fa-solid fa-hdd me-2 text-muted"></i>Port 8089</span> <span class="server-badge">DISK I</span></a>
                    <a class="menu-item-box mt-2 hover-border-blue" href="http://100.100.100.6:8090" target="_blank"><span><i class="fa-solid fa-hdd me-2 text-muted"></i>Port 8090</span> <span class="server-badge">DISK J</span></a>
                    <a class="menu-item-box mt-2 hover-border-blue" href="http://100.100.100.6:8091" target="_blank"><span><i class="fa-solid fa-hdd me-2 text-muted"></i>Port 8091</span> <span class="server-badge">DISK J</span></a>
                    <a class="menu-item-box mt-2 hover-border-blue" href="http://100.100.100.6:8092" target="_blank"><span><i class="fa-solid fa-hdd me-2 text-muted"></i>Port 8092</span> <span class="server-badge">DISK K</span></a>
                    <a class="menu-item-box mt-2 hover-border-blue" href="http://100.100.100.6:8093" target="_blank"><span><i class="fa-solid fa-hdd me-2 text-muted"></i>Port 8093</span> <span class="server-badge">DISK K</span></a>
                    <a class="menu-item-box mt-2 hover-border-blue" href="http://100.100.100.6:8094" target="_blank"><span><i class="fa-solid fa-hdd me-2 text-muted"></i>Port 8094</span> <span class="server-badge">DISK L</span></a>
                    <a class="menu-item-box mt-2 hover-border-blue" href="http://100.100.100.6:8095" target="_blank"><span><i class="fa-solid fa-hdd me-2 text-muted"></i>Port 8095</span> <span class="server-badge">DISK L</span></a>
                </div>
            </div>
          </div>
          <div class="modal-footer bg-light border-0">
             <small class="text-muted w-100 text-center">Clicking a node will open a new tab.</small>
          </div>
        </div>
      </div>
    </div>

    <div class="modal fade" id="mediaServicesModal" tabindex="-1" aria-labelledby="mediaServicesModalLabel" aria-hidden="true">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header modal-header-custom">
            <h5 class="modal-title fw-bold" id="mediaServicesModalLabel"><i class="fa-solid fa-layer-group text-secondary me-2"></i>Media & Services</h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
          </div>
          <div class="modal-body p-4">
            <div class="service-grid">
                <a class="menu-item-box hover-border-red" href="http://100.100.100.2/" target="_blank">
                    <span><i class="fa-solid fa-tv me-2 text-danger"></i>SN Live TV</span> 
                    <i class="fa-solid fa-arrow-up-right-from-square text-muted small"></i>
                </a>

                <a class="menu-item-box hover-border-green" href="http://100.100.100.6:8096" target="_blank">
                    <span><i class="fa-solid fa-play me-2 text-success"></i>SN Emby</span> 
                    <i class="fa-solid fa-arrow-up-right-from-square text-muted small"></i>
                </a>

                <a class="menu-item-box hover-border-purple" href="http://100.100.100.6" target="_blank">
                    <span><i class="fa-solid fa-folder-tree me-2 text-primary"></i>SN FTP</span> 
                    <i class="fa-solid fa-arrow-up-right-from-square text-muted small"></i>
                </a>

                <a class="menu-item-box hover-border-teal" href="http://10.16.100.244/" target="_blank">
                    <span><i class="fa-solid fa-network-wired me-2 text-info"></i>ICC FTP</span> 
                    <i class="fa-solid fa-arrow-up-right-from-square text-muted small"></i>
                </a>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="modal fade" id="helpModal" tabindex="-1" aria-labelledby="helpModalLabel" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered">
            <div class="modal-content">
                <div class="modal-header modal-header-custom">
                    <h5 class="modal-title fw-bold" id="helpModalLabel">
                        <i class="fa-solid fa-circle-question text-info me-2"></i>Help & Support
                    </h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body p-4">
                    
                    <h6 class="fw-bold mb-3"><i class="fa-solid fa-film me-2 text-primary"></i>How to Stream?</h6>
                    <p class="text-muted small">
                        Click the green <strong>"Stream"</strong> button next to any video file. You can watch directly in your browser or open it in an external player like <strong>VLC</strong> or <strong>PotPlayer</strong> for better performance.
                    </p>
                    <hr class="text-secondary opacity-25">

                    <h6 class="fw-bold mb-3"><i class="fa-solid fa-star me-2 text-warning"></i>Recommended Players</h6>
                    
                    <small class="text-uppercase fw-bold text-muted" style="font-size: 0.7rem;">For PC / Laptop</small>
                    <div class="d-flex gap-2 mb-3 mt-1">
                        <a href="https://potplayer.daum.net/" target="_blank" class="btn btn-sm btn-outline-secondary w-50">
                            <i class="fa-solid fa-desktop me-1"></i> PotPlayer
                        </a>
                        <a href="https://www.videolan.org/vlc/" target="_blank" class="btn btn-sm btn-outline-secondary w-50">
                            <i class="fa-solid fa-desktop me-1"></i> VLC Player
                        </a>
                    </div>

                    <small class="text-uppercase fw-bold text-muted" style="font-size: 0.7rem;">For Android / TV</small>
                    <div class="d-flex gap-2 mt-1">
                        <a href="https://play.google.com/store/apps/details?id=com.mxtech.videoplayer.ad" target="_blank" class="btn btn-sm btn-outline-success w-50">
                            <i class="fa-brands fa-google-play me-1"></i> MX Player
                        </a>
                        <a href="https://play.google.com/store/apps/details?id=org.videolan.vlc" target="_blank" class="btn btn-sm btn-outline-success w-50">
                            <i class="fa-brands fa-google-play me-1"></i> VLC Android
                        </a>
                    </div>

                    <hr class="text-secondary opacity-25 mt-3">

                    <h6 class="fw-bold mb-3"><i class="fa-solid fa-screwdriver-wrench me-2 text-danger"></i>Troubleshooting</h6>
                    <ul class="list-unstyled text-muted small mb-0">
                        <li class="mb-1"><i class="fa-solid fa-check me-2 text-success"></i> If download is slow, try using IDM (Internet Download Manager).</li>
                        <li class="mb-1"><i class="fa-solid fa-check me-2 text-success"></i> If a video has no sound in browser, use the "VLC Player" option.</li>
                        <li><i class="fa-solid fa-check me-2 text-success"></i> For missing files, join our Request Group on Telegram.</li>
                    </ul>

                </div>
                <div class="modal-footer bg-light border-0">
                    <a href="https://t.me/+59KXZDQ-K_s2YzRl" target="_blank" class="btn btn-primary w-100">
                        <i class="fa-brands fa-telegram me-2"></i> Contact Support
                    </a>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>

    <script>
        function updateClock() {
            const now = new Date();
            const options = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit', second: '2-digit' };
            document.getElementById('clock').innerText = now.toLocaleDateString('en-US', options);
        }
        setInterval(updateClock, 1000);
        updateClock();

        function filterTable() {
            var input = document.getElementById("fileSearch");
            var filter = input.value.toUpperCase().trim();
            var table = document.getElementById("fileTable");
            var tr = table.getElementsByTagName("tr");
            var hasResults = false;

            for (var i = 1; i < tr.length; i++) {
                var td = tr[i].getElementsByTagName("td")[1];
                if (td) {
                    var txtValue = td.textContent || td.innerText;
                    if (txtValue.indexOf("... (Go Up)") > -1) {
                        tr[i].style.display = "";
                    } 
                    else if (txtValue.toUpperCase().indexOf(filter) > -1) {
                        tr[i].style.display = "";
                        hasResults = true;
                    } 
                    else {
                        tr[i].style.display = "none";
                    }
                }
            }

            var noResDiv = document.getElementById("noResults");
            var searchSpan = document.getElementById("searchText");
            if (!hasResults && filter.length > 0) {
                noResDiv.classList.remove("d-none");
                table.classList.add("d-none");
                searchSpan.innerText = input.value;
            } else {
                noResDiv.classList.add("d-none");
                table.classList.remove("d-none");
            }
        }

        // FALLBACK COPY FUNCTION (Works on HTTP)
        function copyLink(text) {
            if (navigator.clipboard && window.isSecureContext) {
                navigator.clipboard.writeText(text).then(showToast, function(err) {
                    fallbackCopy(text);
                });
            } else {
                fallbackCopy(text);
            }
        }

        function fallbackCopy(text) {
            var textArea = document.createElement("textarea");
            textArea.value = text;
            textArea.style.position = "fixed"; 
            document.body.appendChild(textArea);
            textArea.focus();
            textArea.select();
            try {
                var successful = document.execCommand('copy');
                if(successful) showToast();
                else alert("Copy failed.");
            } catch (err) {
                alert("Unable to copy.");
            }
            document.body.removeChild(textArea);
        }

        function showToast() {
            var toast = document.getElementById("toast");
            toast.className = "show";
            setTimeout(function(){ toast.className = toast.className.replace("show", ""); }, 3000);
        }
    </script>

</body>
</html>