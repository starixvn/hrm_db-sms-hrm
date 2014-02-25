ALTER PROCEDURE [dbo].[ExtensionNO_DELETE_EmployeeInfo]
	@ExtID int,

	@ErrCode int = 0 OUTPUT,
	@ErrMsg varchar(200) = '' OUTPUT	
AS
/*
Created: Tom.Vo@2014-01-04
Task: Delete Employee Extensions Number
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
SET NOCOUNT ON


IF NOT EXISTS(SELECT TOP 1 1 FROM [dbo].[ExtensionNumbers] exg WITH(NOLOCK) WHERE ExtID = @ExtID AND [IsGroup]=0)
BEGIN
	SELECT @ErrCode = 100, @ErrMsg = N'Parameter @ExtID not exists on systems.'
	RETURN
END
ELSE
	DELETE FROM [dbo].[ExtensionNumbers]  WHERE ExtID = @ExtID

SELECT @ErrCode = 0,@ErrMsg=''