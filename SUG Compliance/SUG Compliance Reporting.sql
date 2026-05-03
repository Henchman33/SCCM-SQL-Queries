/* ============================================================
   MECM – Software Update Group Compliance Summary
   Target DB  : CM_P01
   Author     : Steve McKee – System Administrator II
   Description: Returns per-SUG compliance rolled up by
                Compliant / Required / Not Required / Unknown
                with a percentage for executive reporting.
					 SQL Query (SUG_Compliance_Query.sql) — Two queries targeting your CM database:

Summary query — Joins v_UpdateDeploymentSummary, v_UpdateComplianceStatus, and v_R_System to produce one row per Update Group with Compliant / Non-Compliant / Not Required / Unknown counts, plus a calculated Compliance % (Compliant ÷ Required only, so Not Required doesn't skew the number). Filtered to active, CM-client-managed, non-obsolete devices only. Sorted worst-first so your biggest problems surface immediately.
Detail query — Per-device drill-down with OS, last-logged-on user, AD site, and last status change time for investigation work.

Executive HTML Report (SUG_Compliance_Executive_Report.html) — Dark dashboard styled for exec consumption:

5 KPI cards — Group count, total devices, Compliant, Non-Compliant, and Overall Compliance %
Donut chart — State distribution across all groups with a center percentage
Horizontal bar chart — Every group ranked by compliance %, colored red/yellow/green
Detail table — Full breakdown per group with inline compliance bars and status pills
Risk callout section — Auto-flags Critical (<75%), At-Risk (75–94%), and High Unknown groups

To use with real data: Run the first SQL query on your CM database, replace the rows = [...] array in the <script> block at the bottom of the HTML with your actual results, and open in any browser. It's fully self-contained — no dependencies, no server needed.
   ============================================================ */

SELECT
    -- Software Update Group name
    SUG.AssignmentName                          AS [Update Group],

    -- Deployment collection targeted
    SUG.CollectionName                          AS [Target Collection],

    -- Deadline (if set)
    CONVERT(VARCHAR(16), SUG.EnforcementDeadline, 120)
                                                AS [Deadline (UTC)],

    -- Total members in the targeted collection
    COUNT(DISTINCT UCS.ResourceID)              AS [Total Devices],

    -- Compliant: all required updates installed
    SUM(CASE WHEN UCS.Status = 1 THEN 1 ELSE 0 END)
                                                AS [Compliant],

    -- Non-Compliant: one or more required updates missing
    SUM(CASE WHEN UCS.Status = 2 THEN 1 ELSE 0 END)
                                                AS [Non-Compliant],

    -- Not Required: no updates in this group apply to device
    SUM(CASE WHEN UCS.Status = 3 THEN 1 ELSE 0 END)
                                                AS [Not Required],

    -- Unknown: client has not reported status yet
    SUM(CASE WHEN UCS.Status = 0 THEN 1 ELSE 0 END)
                                                AS [Unknown],

    -- Compliance % (Compliant out of Compliant + Non-Compliant)
    CASE
        WHEN SUM(CASE WHEN UCS.Status IN (1,2) THEN 1 ELSE 0 END) = 0
            THEN CAST(0.00 AS DECIMAL(5,2))
        ELSE
            CAST(
                100.0
                * SUM(CASE WHEN UCS.Status = 1 THEN 1 ELSE 0 END)
                / SUM(CASE WHEN UCS.Status IN (1,2) THEN 1 ELSE 0 END)
            AS DECIMAL(5,2))
    END                                         AS [Compliance %]

FROM
    -- Deployment (assignment) info
    v_UpdateDeploymentSummary   AS SUG

    -- Join per-device compliance status for each assignment
    INNER JOIN v_UpdateComplianceStatus AS UCS
        ON  UCS.AssignmentID = SUG.AssignmentID

    -- Join system info for active, client-managed devices only
    INNER JOIN v_R_System        AS SYS
        ON  SYS.ResourceID      = UCS.ResourceID
        AND SYS.Client0         = 1           -- has CM client
        AND SYS.Obsolete0       = 0           -- not obsolete
        AND SYS.Active0         = 1           -- active record

GROUP BY
    SUG.AssignmentName,
    SUG.CollectionName,
    SUG.EnforcementDeadline

ORDER BY
    [Compliance %] ASC,          -- worst groups first
    SUG.AssignmentName;


/* ============================================================
   SECONDARY QUERY – Per-Device Detail (optional drill-down)
   Returns one row per device per Update Group
   ============================================================ */

SELECT
    SUG.AssignmentName                          AS [Update Group],
    SYS.Name0                                   AS [Device Name],
    SYS.User_Name0                              AS [Last Logged-On User],
    OS.Caption0                                 AS [Operating System],
    CASE UCS.Status
        WHEN 0 THEN 'Unknown'
        WHEN 1 THEN 'Compliant'
        WHEN 2 THEN 'Non-Compliant'
        WHEN 3 THEN 'Not Required'
        ELSE        'Other (' + CAST(UCS.Status AS VARCHAR) + ')'
    END                                         AS [Compliance State],
    CONVERT(VARCHAR(16), UCS.LastStatusChangeTime, 120)
                                                AS [Last Status Change (UTC)],
    SYS.AD_Site_Name0                           AS [AD Site]

FROM
    v_UpdateDeploymentSummary   AS SUG
    INNER JOIN v_UpdateComplianceStatus AS UCS
        ON  UCS.AssignmentID    = SUG.AssignmentID
    INNER JOIN v_R_System        AS SYS
        ON  SYS.ResourceID      = UCS.ResourceID
        AND SYS.Client0         = 1
        AND SYS.Obsolete0       = 0
        AND SYS.Active0         = 1
    LEFT  JOIN v_GS_OPERATING_SYSTEM AS OS
        ON  OS.ResourceID       = SYS.ResourceID

ORDER BY
    SUG.AssignmentName,
    UCS.Status,
    SYS.Name0;
