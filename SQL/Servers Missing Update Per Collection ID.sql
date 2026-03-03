DECLARE @CollectionID NVARCHAR(8) = 'P010010E'  -- Change to your Collection ID
;WITH UpdateData AS
(
    SELECT
        rs.ResourceID,
        rs.Name0 AS ComputerName,
        os.Caption0 AS OSName,
        os.Version0 AS OSVersion,
        rs.Resource_Domain_OR_Workgr0 AS Domain,
        rs.Client_Version0 AS ClientVersion,
        ch.ClientActiveStatus AS ClientHealthStatus,
        ui.ArticleID,
        ucs.Status
    FROM v_FullCollectionMembership fcm
    INNER JOIN v_R_System rs 
        ON fcm.ResourceID = rs.ResourceID
    LEFT JOIN v_GS_OPERATING_SYSTEM os 
        ON rs.ResourceID = os.ResourceID
    LEFT JOIN v_CH_ClientSummary ch 
        ON rs.ResourceID = ch.ResourceID
    LEFT JOIN v_UpdateComplianceStatus ucs 
        ON rs.ResourceID = ucs.ResourceID
    LEFT JOIN v_UpdateInfo ui 
        ON ucs.CI_ID = ui.CI_ID
    WHERE fcm.CollectionID = @CollectionID
)

SELECT
    ud.ComputerName,
    ud.OSName,
    ud.OSVersion,
    ud.Domain,

    -- IPv4 Address (Stable Method)
    STUFF((
        SELECT DISTINCT ', ' + ip.IP_Addresses0
        FROM v_RA_System_IPAddresses ip
        WHERE ip.ResourceID = ud.ResourceID
          AND ip.IP_Addresses0 NOT LIKE '%:%'
        FOR XML PATH('')
    ),1,2,'') AS IPv4Address,

    ud.ClientVersion,

    CASE 
        WHEN ud.ClientHealthStatus = 1 THEN 'Healthy'
        ELSE 'Unhealthy'
    END AS ClientHealth,

    -- Missing KBs in one line
    STRING_AGG(
        CASE WHEN ud.Status = 2 THEN ud.ArticleID END, ', '
    ) AS MissingKBs,

    SUM(CASE WHEN ud.Status = 3 THEN 1 ELSE 0 END) AS InstalledUpdates,
    SUM(CASE WHEN ud.Status = 2 THEN 1 ELSE 0 END) AS MissingUpdates,

    CASE 
        WHEN COUNT(ud.Status) = 0 THEN 100
        ELSE CAST(
            (SUM(CASE WHEN ud.Status = 3 THEN 1 ELSE 0 END) * 100.0)
            / COUNT(ud.Status)
        AS DECIMAL(5,2))
    END AS CompliancePercent

FROM UpdateData ud
GROUP BY
    ud.ResourceID,
    ud.ComputerName,
    ud.OSName,
    ud.OSVersion,
    ud.Domain,
    ud.ClientVersion,
    ud.ClientHealthStatus
ORDER BY ud.ComputerName

