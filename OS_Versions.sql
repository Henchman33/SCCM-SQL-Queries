select Distinct
v_R_System.Name0,
v_GS_NETWORK_ADAPTER_CONFIGURATION.IPAddress0,
v_GS_NETWORK_ADAPTER_CONFIGURATION.DNSHostName0,
v_GS_NETWORK_ADAPTER_CONFIGURATION.DNSDomain0,
v_GS_OPERATING_SYSTEM.Caption0 as 'Operating System', 
v_GS_OPERATING_SYSTEM.CSDVersion0 as 'Service Pack',
dbo.v_FullCollectionMembership.SiteCode,
CASE
WHEN dbo.v_FullCollectionMembership.SiteCode LIKE 'A%' THEN 'India'
WHEN dbo.v_FullCollectionMembership.SiteCode LIKE 'O%' THEN 'UK'
ELSE 'Unidentified' END AS 'Country'
 from v_R_System 
 INNER JOIN dbo.v_FullCollectionMembership ON dbo.v_R_System.ResourceID = dbo.v_FullCollectionMembership.ResourceID 
 Inner Join v_GS_OPERATING_SYSTEM ON v_GS_OPERATING_SYSTEM.Resourceid=v_R_System.Resourceid
 Inner join v_GS_NETWORK_ADAPTER_CONFIGURATION ON v_GS_NETWORK_ADAPTER_CONFIGURATION.ResourceID=v_R_System.ResourceID
 where (dbo.v_FullCollectionMembership.SiteCode != 'NULL') and (Operating_System_Name_and0 != 'NULL') 
 and (IPAddress0 IS NOT NULL) AND (IPAddress0 LIKE '10.%')
 and (Active0 = '1') and (Client0 = '1')
ORDER BY dbo.v_FullCollectionMembership.SiteCode
