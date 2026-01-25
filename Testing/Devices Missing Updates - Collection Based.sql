
--Create a lookup table for Windows Update / SCCM error descriptions:

-- Example lookup table
CREATE TABLE dbo.UpdateErrorCodeLookup (
    ErrorCode INT PRIMARY KEY,
    ErrorDescription NVARCHAR(4000)
);

-- Example data
INSERT INTO dbo.UpdateErrorCodeLookup VALUES
(0x80070005, 'Access denied'),
(0x8024200D, 'Update needs to be downloaded again'),
(0x80244022, 'WU_E_PT_HTTP_STATUS_SERVICE_UNAVAIL'),
(0x800F081F, 'CBS source files not found');

--------------------------------------------------------------------------

DECLARE @CollectionID NVARCHAR(8) = 'ABC00001'; -- CHANGE ME

/* ==========================================================
   Missing Updates (last 3 months)
   ========================================================== */
WITH MissingUpdates AS (
    SELECT
        ucs.ResourceID,
        STRING_AGG(ui.ArticleID, ', ') AS MissingKBs_Last3Months
    FROM v_UpdateComplianceStatus ucs
    JOIN v_UpdateInfo ui ON ui.CI_ID = ucs.CI_ID
    WHERE
        ucs.Status = 2
        AND ui.DateRevised >= DATEADD(MONTH, -3, GETDATE())
    GROUP BY ucs.ResourceID
),

/* ==========================================================
   Software Update Group compliance per device
   ========================================================== */
UpdateGroupCompliance AS (
    SELECT
        ucs.ResourceID,
        STRING_AGG(
            sug.Title + ' (' +
            CAST(
                COUNT(CASE WHEN ucs.Status = 1 THEN 1 END) * 100
                / NULLIF(COUNT(*), 0)
                AS VARCHAR(4)
            ) + '%)',
            '; '
        ) AS UpdateGroupCompliance
    FROM v_UpdateComplianceStatus ucs
    JOIN v_CIRelation cir ON cir.ToCIID = ucs.CI_ID
    JOIN v_CIInfo ci ON ci.CI_ID = cir.FromCIID
    JOIN v_UpdateGroupInfo sug ON sug.CI_ID = ci.CI_ID
    GROUP BY ucs.ResourceID, sug.Title
),

/* ==========================================================
   Error codes with descriptions
   ========================================================== */
UpdateErrors AS (
    SELECT
        ucs.ResourceID,
        STRING_AGG(
            CAST(ucs.LastErrorCode AS VARCHAR(20)) + ' - ' +
            ISNULL(el.ErrorDescription, 'Unknown error'),
            '; '
        ) AS UpdateErrorsWithDescriptions
    FROM v_UpdateComplianceStatus ucs
    LEFT JOIN dbo.UpdateErrorCodeLookup el
        ON el.ErrorCode = ucs.LastErrorCode
    WHERE ucs.LastErrorCode IS NOT NULL
    GROUP BY ucs.ResourceID
)

/* ==========================================================
   PRIMARY ONE-LINE-PER-DEVICE REPORT
   ========================================================== */
SELECT DISTINCT
    sys.Name0 AS DeviceName,
    os.Caption0 AS OperatingSystem,
    sys.Resource_Domain_OR_Workgr0 AS DomainName,
    ip.IP_Addresses0 AS IPAddress,

    cli.ClientVersion AS SCCMClientVersion,

    CASE
        WHEN cli.ClientActiveStatus = 1 THEN 'Yes'
        WHEN cli.ClientActiveStatus = 0 THEN 'No'
        ELSE 'Unknown'
    END AS ClientInstalled,

    ch.ClientStateDescription AS ClientInstallState,
    ch.ClientStateErrorCode AS ClientInstallErrorCode,

    mu.MissingKBs_Last3Months,
    ugc.UpdateGroupCompliance,
    ue.UpdateErrorsWithDescriptions

FROM v_FullCollectionMembership fcm
JOIN v_R_System sys
    ON sys.ResourceID = fcm.ResourceID

LEFT JOIN v_GS_OPERATING_SYSTEM os
    ON os.ResourceID = sys.ResourceID

LEFT JOIN v_GS_NETWORK_ADAPTER_CONFIGURATION ip
    ON ip.ResourceID = sys.ResourceID
   AND ip.IPEnabled0 = 1

LEFT JOIN v_SMS_Client cli
    ON cli.ResourceID = sys.ResourceID

LEFT JOIN v_CH_ClientSummary ch
    ON ch.ResourceID = sys.ResourceID

LEFT JOIN MissingUpdates mu
    ON mu.ResourceID = sys.ResourceID

LEFT JOIN UpdateGroupCompliance ugc
    ON ugc.ResourceID = sys.ResourceID

LEFT JOIN UpdateErrors ue
    ON ue.ResourceID = sys.ResourceID

WHERE fcm.CollectionID = @CollectionID
ORDER BY sys.Name0;

-----------------------------------------------------------------------

SCCM – Update Compliance & Client Health Report

---------------------------------------------------------------------

🔹 Report Parameters

Create these once at the report level:

Parameter	Type	Notes
CollectionID	Text	Default to a prod collection
ShowOnlyServers2022	Boolean	Optional filter
ShowOnlyNonCompliant	Boolean	Optional
🔹 DATASET 1 – DEVICE DETAIL (MAIN TABLE)

Use your PRIMARY consolidated SQL script
(This powers the big per-device table)

Modify WHERE clause to accept SSRS parameters:

WHERE fcm.CollectionID = @CollectionID
AND (
    @ShowOnlyServers2022 = 0
    OR os.Caption0 LIKE '%Server 2022%'
)
AND (
    @ShowOnlyNonCompliant = 0
    OR mu.MissingKBs_Last3Months IS NOT NULL
)

----------------------------------------------------------------------

📋 SSRS Visual

Tablix

One row per device

CanGrow = TRUE for:

Missing KBs

Update Group Compliance

Error Descriptions

🔹 DATASET 2 – UPDATE GROUP COMPLIANCE SUMMARY

Use the SSRS summary query

📊 SSRS Visual

Matrix or tablix

Optional bar chart:

X-axis: Update Group

Y-axis: Percent Compliant

🔹 DATASET 3 – OVERALL HEALTH SUMMARY (OPTIONAL BUT POWERFUL)
SELECT
    COUNT(*) AS TotalDevices,
    SUM(CASE WHEN ClientInstalled = 'Yes' THEN 1 ELSE 0 END) AS ClientsInstalled,
    SUM(CASE WHEN ClientInstalled <> 'Yes' THEN 1 ELSE 0 END) AS ClientsMissing
FROM (
    -- Reference Dataset 1 query here
) d;

📊 SSRS Visual

KPI tiles

Gauge or cards

🔹 SSRS REPORT LAYOUT (SINGLE REPORT PAGE)
-------------------------------------------------
| Header: Collection | Run Date | Filters      |
-------------------------------------------------
| KPI Summary (Dataset 3)                        |
-------------------------------------------------
| Update Group Compliance Chart (Dataset 2)     |
-------------------------------------------------
| Device Detail Table (Dataset 1)                |
-------------------------------------------------

🔹 DRILL-THROUGH (OPTIONAL, STILL ONE REPORT)

You can add:

Click Device → Filter table to single device

Click Update Group → Filter to that group

No extra reports needed.

🔹 WHY THIS IS BEST PRACTICE

✔ Single report to maintain
✔ Shared parameters
✔ Clean performance
✔ Export-friendly
✔ Executive + engineer views in one place

🔹 IMPORTANT SCCM SSRS NOTES

Use Stored Credentials for the SCCM SQL data source

Avoid subreports (performance + security pain)

Always filter on CollectionID

🔹 Want me to:

Convert SQL to stored procedures?

Build the exact SSRS layout steps?

Add row color rules (red = missing updates)?

Add clickable KB links?

Say the word and I’ll give you production-ready SSRS instructions.

----------------------------------------------------------------------------------

Below is a full, production-ready SSRS build guide for ONE report, using the SQL you already have, with:

✅ Color rules
✅ Clickable KB article IDs
✅ Clear layout
✅ SCCM best practices

No subreports. No hacks. This is how ConfigMgr teams build enterprise SSRS reports.

🧾 SSRS REPORT: FULL BUILD GUIDE
📌 Report Name
SCCM – Update Compliance & Client Health (Single Report)

1️⃣ DATA SOURCE (ONCE)

Type: Microsoft SQL Server
Connection string:

Data Source=CM01.contoso.com;Initial Catalog=CM_ABC


Credentials:
☑ Use stored credentials
☑ Windows Authentication
☑ Least-privileged SQL account

2️⃣ REPORT PARAMETERS

Create these report-level parameters:

🔹 CollectionID

Type: Text

Prompt: Collection ID

Default: ABC00001

🔹 ShowOnlyServers2022

Type: Boolean

Default: False

🔹 ShowOnlyNonCompliant

Type: Boolean

Default: False

3️⃣ DATASET 1 – DEVICE DETAIL (MAIN TABLE)

Paste the full primary SQL script and replace the WHERE clause with:

WHERE fcm.CollectionID = @CollectionID
AND (
    @ShowOnlyServers2022 = 0
    OR os.Caption0 LIKE '%Server 2022%'
)
AND (
    @ShowOnlyNonCompliant = 0
    OR mu.MissingKBs_Last3Months IS NOT NULL
)


Dataset name: DeviceDetail

4️⃣ DATASET 2 – UPDATE GROUP SUMMARY

Use the update group summary SQL.

Dataset name: UpdateGroupSummary

5️⃣ REPORT LAYOUT (TOP → BOTTOM)
🔹 SECTION 1 – HEADER

Add textboxes:

SCCM – Update Compliance & Client Health
Collection: =Parameters!CollectionID.Value
Run Date: =Globals!ExecutionTime

🔹 SECTION 2 – UPDATE GROUP COMPLIANCE CHART

Insert → Chart → Bar Chart

Dataset: UpdateGroupSummary

Category: SoftwareUpdateGroup

Value: PercentCompliant

🎨 Color Rules (Chart)

≥ 95% → Green

85–94% → Orange

< 85% → Red

(Expression on series color)

=IIF(Fields!PercentCompliant.Value >= 95, "Green",
 IIF(Fields!PercentCompliant.Value >= 85, "Orange", "Red"))

🔹 SECTION 3 – DEVICE DETAIL TABLE

Insert → Tablix
Dataset: DeviceDetail

📋 Columns (Recommended Order)

DeviceName

OperatingSystem

DomainName

IPAddress

SCCMClientVersion

ClientInstalled

ClientInstallState

MissingKBs_Last3Months

UpdateGroupCompliance

UpdateErrorsWithDescriptions

6️⃣ COLOR RULES (CRITICAL PART)
🔴 Row Background – Missing Updates

Row → BackgroundColor:

=IIF(IsNothing(Fields!MissingKBs_Last3Months.Value),
     "White",
     "#FFF4CCCC")

🟠 Client Not Installed

Textbox: ClientInstalled

=IIF(Fields!ClientInstalled.Value = "Yes",
     "LightGreen",
     IIF(Fields!ClientInstalled.Value = "No",
         "#FFFFC000",
         "#FFD9D9D9"))

🔴 Client Install Errors

Textbox: ClientInstallErrorCode

=IIF(IsNothing(Fields!ClientInstallErrorCode.Value),
     "Transparent",
     "#FFFF9999")

7️⃣ CLICKABLE KB ARTICLE IDS
🔗 Convert KBs into Microsoft Update links

Select the MissingKBs_Last3Months textbox:

Action → Go to URL

="https://catalog.update.microsoft.com/Search.aspx?q=" 
 & Replace(Fields!MissingKBs_Last3Months.Value, ", ", "+")


✔ Clicking opens Microsoft Update Catalog
✔ Works for multiple KBs
✔ Safe for exports

8️⃣ COLUMN FORMATTING (IMPORTANT)

For text-heavy columns:

CanGrow = True

VerticalAlign = Top

Font: Segoe UI / Calibri 9–10pt

9️⃣ SORTING & INTERACTIVITY
Default sort:

Missing updates first

Then device name

=IIF(IsNothing(Fields!MissingKBs_Last3Months.Value), 1, 0)

🔟 EXPORT SAFETY

✔ Excel: works
✔ CSV: works
✔ PDF: works

Avoid:

Subreports

Custom assemblies

🧠 WHAT THIS REPORT GIVES YOU

✔ Executive summary
✔ Engineer troubleshooting
✔ One report to maintain
✔ Drill-ready
✔ Production-safe


==========================================================================================================

Software Update Group compliance
