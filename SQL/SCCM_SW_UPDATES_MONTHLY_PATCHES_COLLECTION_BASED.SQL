-- Declare your collection ID variable - CHANGE THIS VALUE
DECLARE @TargetCollectionID NVARCHAR(8) = 'P010010E'; -- Default is 'All Systems'

-- CTE to get collection membership
WITH CollectionMembers AS (
    SELECT DISTINCT 
        RSC.ResourceID,
        RSC.Name0 AS ComputerName
    FROM v_FullCollectionMembership FCM
    INNER JOIN v_R_System RSC ON FCM.ResourceID = RSC.ResourceID
    WHERE FCM.CollectionID = @TargetCollectionID
        AND RSC.ResourceType = 5 -- ResourceType 5 = System resources [citation:1][citation:4]
        AND RSC.Name0 IS NOT NULL
        AND RSC.Client0 = 1 -- Only include clients (Client0 = 1 means client installed) [citation:1]
),

-- Computer details including OS, Domain, IP, Client Version, Health
ComputerDetails AS (
    SELECT 
        CM.ComputerName,
        OS.Caption0 AS OperatingSystem,
        OS.Version0 AS OSVersion,
        SYS.User_Domain0 AS [Domain],
        -- Get first IPv4 address from v_RA_System_IPAddresses [citation:1][citation:4]
        (
            SELECT TOP 1 IP.IP_Addresses0
            FROM v_RA_System_IPAddresses IP
            WHERE IP.ResourceID = CM.ResourceID
                AND IP.IP_Addresses0 IS NOT NULL
                AND IP.IP_Addresses0 NOT LIKE ':%' -- Exclude IPv6 (contains colons)
                AND IP.IP_Addresses0 NOT LIKE 'fe80:%' -- Exclude link-local IPv6
        ) AS IPv4Address,
        SYS.Client_Version0 AS SCCMClientVersion,
        -- Determine client health using v_CH_ClientSummary [citation:2][citation:5][citation:7]
        CASE 
            WHEN CS.LastOnline IS NOT NULL 
                 AND DATEDIFF(day, CS.LastOnline, GETDATE()) <= 7 
            THEN 'Healthy'
            WHEN CS.LastOnline IS NOT NULL 
                 AND DATEDIFF(day, CS.LastOnline, GETDATE()) > 7 
            THEN 'Inactive'
            WHEN SYS.Client_Version0 IS NOT NULL THEN 'Client Installed - Status Unknown'
            ELSE 'Not Installed'
        END AS ClientHealth,
        CM.ResourceID,
        CS.LastOnline
    FROM CollectionMembers CM
    INNER JOIN v_R_System SYS ON CM.ResourceID = SYS.ResourceID
    LEFT JOIN v_GS_OPERATING_SYSTEM OS ON CM.ResourceID = OS.ResourceID
    -- Join to client status views for health information [citation:2][citation:7]
    LEFT JOIN v_CH_ClientSummary CS ON CM.ResourceID = CS.ResourceID
),

-- Missing updates for the collection with KB Article IDs
MissingUpdates AS (
    SELECT 
        CD.ComputerName,
        CD.OperatingSystem,
        CD.OSVersion,
        CD.[Domain],
        CD.IPv4Address,
        CD.SCCMClientVersion,
        CD.ClientHealth,
        -- Concatenate missing KB articles for each computer
        STUFF((
            SELECT DISTINCT ', ' + UI.ArticleID
            FROM v_UpdateComplianceStatus UCS
            INNER JOIN v_UpdateInfo UI ON UCS.CI_ID = UI.CI_ID
            WHERE UCS.ResourceID = CD.ResourceID
                AND UCS.Status = 2 -- Status 2 = Required (missing) [citation:1][citation:2]
                AND UI.ArticleID IS NOT NULL
                AND UI.ArticleID != ''
                -- Filter for monthly updates (last 60 days)
                AND UI.DatePosted >= DATEADD(day, -60, GETDATE())
            FOR XML PATH('')
        ), 1, 2, '') AS MissingKBArticles,
        -- Count of missing updates for this computer
        ISNULL((
            SELECT COUNT(DISTINCT UI.ArticleID)
            FROM v_UpdateComplianceStatus UCS
            INNER JOIN v_UpdateInfo UI ON UCS.CI_ID = UI.CI_ID
            WHERE UCS.ResourceID = CD.ResourceID
                AND UCS.Status = 2
                AND UI.ArticleID IS NOT NULL
                AND UI.ArticleID != ''
                AND UI.DatePosted >= DATEADD(day, -60, GETDATE())
        ), 0) AS MissingCount,
        CD.ResourceID
    FROM ComputerDetails CD
)

-- Main query: Computer details with missing KB articles
SELECT 
    MU.ComputerName,
    MU.OperatingSystem,
    MU.OSVersion + ISNULL(' ' + MU.OperatingSystem, '') AS OperatingSystemName,
    MU.[Domain],
    ISNULL(MU.IPv4Address, 'Unknown') AS IPv4Address,
    MU.SCCMClientVersion,
    MU.ClientHealth,
    ISNULL(MU.MissingKBArticles, 'No missing updates') AS MissingKBArticles,
    MU.MissingCount
FROM MissingUpdates MU
WHERE MU.MissingCount > 0  -- Only show computers with missing updates
ORDER BY MU.ComputerName;

-- Summary: Compliance percentage for the collection
SELECT 
    'Collection Summary' AS ReportType,
    @TargetCollectionID AS CollectionID,
    COUNT(DISTINCT CD.ComputerName) AS TotalComputers,
    SUM(CASE WHEN MU.MissingCount > 0 THEN 1 ELSE 0 END) AS ComputersWithMissingUpdates,
    SUM(CASE WHEN MU.MissingCount = 0 THEN 1 ELSE 0 END) AS CompliantComputers,
    -- Compliance percentage calculation
    CAST(
        ROUND(
            100.0 * SUM(CASE WHEN MU.MissingCount = 0 THEN 1 ELSE 0 END) / 
            NULLIF(COUNT(DISTINCT CD.ComputerName), 0), 
        2) AS DECIMAL(5,2)
    ) AS CompliancePercentage,
    SUM(MU.MissingCount) AS TotalMissingUpdates,
    -- Summary of installed to missing ratio
    CAST(
        ROUND(
            100.0 * SUM(CASE WHEN MU.MissingCount = 0 THEN 1 ELSE 0 END) / 
            NULLIF(COUNT(DISTINCT CD.ComputerName), 0), 
        2) AS DECIMAL(5,2)
    ) AS InstalledPercentage
FROM ComputerDetails CD
LEFT JOIN MissingUpdates MU ON CD.ResourceID = MU.ResourceID
WHERE CD.SCCMClientVersion IS NOT NULL; -- Only count computers with SCCM client
