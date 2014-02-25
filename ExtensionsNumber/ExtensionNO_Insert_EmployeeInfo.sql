ALTER PROCEDURE [dbo].[ExtensionNO_Insert_EmployeeInfo]
	@FullName nvarchar(200)=NULL,
    @NickName nvarchar(100)=NULL,
    @ExtensionNo nvarchar(200),
    @IsInternal bit,
    @EmpID int=NULL,
    @GroupID int,
    @OrderNo smallint=1,

	@ErrCode int = 0 OUTPUT,
	@ErrMsg varchar(200) = '' OUTPUT	
AS
/*
Created: Tom.Vo@2014-01-04
Task: Insert Employee Extensions Number
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
SET NOCOUNT ON

DECLARE @IsGroup bit=0

SET @IsInternal = ISNULL(@IsInternal,1)
IF @IsInternal = 1
BEGIN
	IF NOT EXISTS(SELECT TOP 1 1 FROM dbo.Employee WITH(NOLOCK) WHERE EmpID = @EmpID)
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = N'Parameter EmpID not exists on systems.'
		RETURN
	END
	IF EXISTS(SELECT TOP 1 1 FROM [dbo].[ExtensionNumbers] exg WITH(NOLOCK) WHERE EmpID = @EmpID AND GroupID = @GroupID AND IsInternal = 1)
	BEGIN
		SELECT @ErrCode = 102, @ErrMsg = N'EmpID  exists on systems.'
		RETURN
	END
END
ELSE
BEGIN
	IF NOT EXISTS(SELECT TOP 1 1 FROM [dbo].[ExtensionNumbers] exg WITH(NOLOCK) WHERE ExtID = @GroupID AND [IsGroup]=1  AND IsInternal = 0)
	BEGIN
		SELECT @ErrCode = 103, @ErrMsg = N'Parameter EmpID not exists on systems.'
		RETURN
	END
	IF EXISTS(SELECT TOP 1 1 FROM [dbo].[ExtensionNumbers] exg WITH(NOLOCK) WHERE EmpID = @EmpID AND GroupID = @GroupID AND IsInternal = 0)
	BEGIN
		SELECT @ErrCode = 104, @ErrMsg = N'EmpID  exists on systems.'
		RETURN
	END
END

IF @IsInternal = 1
BEGIN
	IF NOT EXISTS(SELECT TOP 1 1 FROM [dbo].[ExtensionNumbers] exg WITH(NOLOCK) WHERE [GroupID] = @GroupID AND [IsInternal] = 1)
	BEGIN
		INSERT INTO [ExtensionNumbers]
			(
			   [FullName]
			  ,[NickName]
			  ,[ExtensionNo]
			  ,IsInternal
			  ,[IsGroup]
			  ,[EmpID]
			  ,[GroupID]
			  ,[OrderNo]
			)
		SELECT  N'' [FullName]
			  ,'' [NickName]
			  ,'' [ExtensionNo]
			  ,1 IsInternal
			  ,1 [IsGroup]
			  ,NULL [EmpID]
			  ,@GroupID [GroupID]
			  ,MAX([OrderNo]) FROM [dbo].[ExtensionNumbers] exg WITH(NOLOCK) WHERE [GroupID] <> @GroupID AND [IsInternal] = 1
	END

	INSERT INTO [dbo].[ExtensionNumbers]
			   ([FullName]
			   ,[NickName]
			   ,[ExtensionNo]
			   ,[IsInternal]
			   ,[IsGroup]
			   ,[EmpID]
			   ,[GroupID]
			   ,[OrderNo])
		 VALUES
			   (@FullName,
				@NickName,
				@ExtensionNo,
				@IsInternal,
				@IsGroup,
				@EmpID,
				@GroupID,
				@OrderNo)

END
ELSE
BEGIN
	INSERT INTO [dbo].[ExtensionNumbers]
			   ([FullName]
			   ,[NickName]
			   ,[ExtensionNo]
			   ,[IsInternal]
			   ,[IsGroup]
			   ,[EmpID]
			   ,[GroupID]
			   ,[OrderNo])
		 VALUES
			   (@FullName,
				@NickName,
				@ExtensionNo,
				@IsInternal,
				@IsGroup,
				NULL,
				@GroupID,
				@OrderNo)
END
SET @ErrCode=0