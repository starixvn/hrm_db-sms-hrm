ALTER PROCEDURE [dbo].[ExtensionNO_Update_GroupExternal]
	@ExtID int,
	@FullName nvarchar(200)=NULL,

	@ErrCode int = 0 OUTPUT,
	@ErrMsg varchar(200) = '' OUTPUT	
AS
/*
Created: Tom.Vo@2014-01-04
Task: Update Group Extensions Number
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
SET NOCOUNT ON

DECLARE @IsGroup bit=0


IF EXISTS(SELECT TOP 1 1 FROM [dbo].[ExtensionNumbers] exg WITH(NOLOCK) WHERE FullName = @FullName AND [IsGroup]=1  AND IsInternal = 0 AND ExtID <> @ExtID)
BEGIN
	SELECT @ErrCode = 100, @ErrMsg = N'Group Name exists on systems.'
	RETURN
END

UPDATE [dbo].[ExtensionNumbers] WITH(ROWLOCK)
SET [FullName]=@FullName
	,[NickName]=[FullName] 
WHERE ExtID = @ExtID AND [IsGroup]=1 AND IsInternal = 0

SET @ErrCode=0

