ALTER PROCEDURE [dbo].WorkingTimeRequest_ResetRequest_byMember
	@RequestID bigint,	
	@EmpId int,
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT
AS
/*
Created: Tom.Vo@2013-11-06
Task: Reset Status request form (main SP)
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
SET NOCOUNT ON


EXEC [dbo].WorkingTimeRequest_ResetRequest_byMember_6
	@RequestID =@RequestID ,	
	@EmpId =@EmpId ,
	@ErrCode = @ErrCode  OUTPUT,
	@ErrMsg = @ErrMsg OUTPUT