ALTER PROCEDURE [dbo].[ExtensionNO_DELETE_GroupExternal]
	@ExtID int,

	@ErrCode int = 0 OUTPUT,
	@ErrMsg varchar(200) = '' OUTPUT	
AS
/*
Created: Tom.Vo@2014-01-04
Task: Delete Group Extensions Number
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
SET NOCOUNT ON


IF NOT EXISTS(SELECT TOP 1 1 FROM [dbo].[ExtensionNumbers] exg WITH(NOLOCK) WHERE ExtID = @ExtID AND [IsGroup]=1)
BEGIN
	SELECT @ErrCode = 100, @ErrMsg = N'Parameter @ExtID not exists on systems.'
	RETURN
END
IF EXISTS(SELECT TOP 1 1 FROM [dbo].[ExtensionNumbers] exg WITH(NOLOCK) WHERE GroupID = @ExtID AND [IsGroup]=0  AND IsInternal = 0 )
BEGIN
	SELECT @ErrCode = 101, @ErrMsg = N'Team is not empty so cannot delete it'
	RETURN
END

DELETE FROM [dbo].[ExtensionNumbers]  WHERE ExtID = @ExtID

SELECT @ErrCode = 0,@ErrMsg=''