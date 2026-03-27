--Specific Software Update Deployment Failed Errors with Description
Declare @DeploymentName as Varchar(255)
Set @DeploymentName = 'All Server 2025 Updates (Odd)'
Select
Vrs.Name0 as 'MachineName',
Vrs.User_Name0 as 'UserName',
assc.LastEnforcementMessageTime as 'LastEnforcementTime',
assc.LastEnforcementErrorID&0x0000FFFF as 'ErrorStatusID',
isnull(master.dbo.fn_varbintohexstr(CONVERT(VARBINARY(8),CONVERT(int,assc.LastEnforcementErrorCode))), 0) as 'ErrorCode',
assc.LastEnforcementErrorCode as 'ErrorCodeInt',
Asi.MessageName as 'MessageName'
from V_CIAssignment cia
join V_UpdateAssignmentStatus_Live assc on assc.AssignmentID = cia.AssignmentID
inner join v_AssignmentState_Combined Ac on Ac.ResourceID = assc.ResourceID
inner join V_AdvertisementStatusInformation Asi on Asi.MessageID = Ac.LastStatusMessageID
and isnull(assc.IsCompliant, 0) = 0
and assc.LastEnforcementMessageID in (6,9)
and assc.LastEnforcementErrorCode Not in (0)
join v_R_System Vrs on assc.ResourceID = Vrs.ResourceID and isnull (Vrs.Obsolete0,0) = 0
where cia.AssignmentName = @DeploymentName


--Specific Software Update Deployment Failed Errors with Description
--Declare @DeploymentName as Varchar(255)
Set @DeploymentName = 'All Server 2022 Updates (Odd)'
Select
Vrs.Name0 as 'MachineName',
Vrs.User_Name0 as 'UserName',
assc.LastEnforcementMessageTime as 'LastEnforcementTime',
assc.LastEnforcementErrorID&0x0000FFFF as 'ErrorStatusID',
isnull(master.dbo.fn_varbintohexstr(CONVERT(VARBINARY(8),CONVERT(int,assc.LastEnforcementErrorCode))), 0) as 'ErrorCode',
assc.LastEnforcementErrorCode as 'ErrorCodeInt',
Asi.MessageName as 'MessageName'
from V_CIAssignment cia
join V_UpdateAssignmentStatus_Live assc on assc.AssignmentID = cia.AssignmentID
inner join v_AssignmentState_Combined Ac on Ac.ResourceID = assc.ResourceID
inner join V_AdvertisementStatusInformation Asi on Asi.MessageID = Ac.LastStatusMessageID
and isnull(assc.IsCompliant, 0) = 0
and assc.LastEnforcementMessageID in (6,9)
and assc.LastEnforcementErrorCode Not in (0)
join v_R_System Vrs on assc.ResourceID = Vrs.ResourceID and isnull (Vrs.Obsolete0,0) = 0
where cia.AssignmentName = @DeploymentName


--Specific Software Update Deployment Failed Errors with Description
--Declare @DeploymentName as Varchar(255)
Set @DeploymentName = 'All Server 2016 and 2019 Updates (Odd)'
Select
Vrs.Name0 as 'MachineName',
Vrs.User_Name0 as 'UserName',
assc.LastEnforcementMessageTime as 'LastEnforcementTime',
assc.LastEnforcementErrorID&0x0000FFFF as 'ErrorStatusID',
isnull(master.dbo.fn_varbintohexstr(CONVERT(VARBINARY(8),CONVERT(int,assc.LastEnforcementErrorCode))), 0) as 'ErrorCode',
assc.LastEnforcementErrorCode as 'ErrorCodeInt',
Asi.MessageName as 'MessageName'
from V_CIAssignment cia
join V_UpdateAssignmentStatus_Live assc on assc.AssignmentID = cia.AssignmentID
inner join v_AssignmentState_Combined Ac on Ac.ResourceID = assc.ResourceID
inner join V_AdvertisementStatusInformation Asi on Asi.MessageID = Ac.LastStatusMessageID
and isnull(assc.IsCompliant, 0) = 0
and assc.LastEnforcementMessageID in (6,9)
and assc.LastEnforcementErrorCode Not in (0)
join v_R_System Vrs on assc.ResourceID = Vrs.ResourceID and isnull (Vrs.Obsolete0,0) = 0
where cia.AssignmentName = @DeploymentName

Set @DeploymentName = 'All Server 2012 and 2012 R2 Updates (Odd)'
Select
Vrs.Name0 as 'MachineName',
Vrs.User_Name0 as 'UserName',
assc.LastEnforcementMessageTime as 'LastEnforcementTime',
assc.LastEnforcementErrorID&0x0000FFFF as 'ErrorStatusID',
isnull(master.dbo.fn_varbintohexstr(CONVERT(VARBINARY(8),CONVERT(int,assc.LastEnforcementErrorCode))), 0) as 'ErrorCode',
assc.LastEnforcementErrorCode as 'ErrorCodeInt',
Asi.MessageName as 'MessageName'
from V_CIAssignment cia
join V_UpdateAssignmentStatus_Live assc on assc.AssignmentID = cia.AssignmentID
inner join v_AssignmentState_Combined Ac on Ac.ResourceID = assc.ResourceID
inner join V_AdvertisementStatusInformation Asi on Asi.MessageID = Ac.LastStatusMessageID
and isnull(assc.IsCompliant, 0) = 0
and assc.LastEnforcementMessageID in (6,9)
and assc.LastEnforcementErrorCode Not in (0)
join v_R_System Vrs on assc.ResourceID = Vrs.ResourceID and isnull (Vrs.Obsolete0,0) = 0
where cia.AssignmentName = @DeploymentName


