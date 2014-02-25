USE [HRM_SMS]
GO
/****** Object:  StoredProcedure [dbo].[Employee_Infor_update]    Script Date: 2013-10-29 4:20:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[Employee_Information_UpdateByEmpid] 
	-- Add the parameters for the stored procedure here
	@EmpId int
	--,@FullName nvarchar(50)=''
	,@DOB smalldatetime=NULL
	,@Phone varchar(50)=NULL
	,@Gender tinyint=NULL	
	,@Skype varchar(100)=''
	,@Yahoo varchar(100)=''
	,@Marriage tinyint = 1

	,@PermanentAddress nvarchar(250)=''
	,@CurrentAddress nvarchar(250)=''
	,@IdCardNumber varchar(20)=''
	,@PassportNo varchar(35)=''
	,@PassportExp datetime=''
	,@ChineseName nvarchar(200)=NULL
	
	,@ModifiedDate datetime
	,@ModifiedBy int
	,@CountryCode varchar(5)=NULL	
	
	,@PlaceOfbirth nvarchar(250)=''
	,@Ethnic nvarchar(250)=''
	,@Native nvarchar(250)=''
	,@Religion nvarchar(250)=''
	,@DateOfIDCard datetime=NULL
	,@PlaceOfIDCard nvarchar(250)=''
	,@HomePhone nvarchar(250)=''
	,@Qualification nvarchar(300)=''
	,@Major nvarchar(300)=''

	,@ErrCode int = 0 OUTPUT
	,@ErrMsg varchar(200) = '' OUTPUT	
AS
/*
Created: TOM
Task: UPDATE an employee Information 
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/

BEGIN

	SET NOCOUNT ON;
	
	BEGIN TRY
		BEGIN TRANSACTION;	
			UPDATE dbo.Employee WITH(ROWLOCK)
		   SET --FullName =@FullName 
				DOB =@DOB 
				,Phone =@Phone 
				,Gender = @Gender 
				,Skype =@Skype 
				,Yahoo =@Yahoo 
				,Marriage = @Marriage 
				,ModifiedDate =@ModifiedDate 
				,ModifiedBy =@ModifiedBy 
				,PermanentAddress =@PermanentAddress 
				,CurrentAddress =@CurrentAddress 
				,IdCardNumber =@IdCardNumber 
				,PassportNo =@PassportNo 
				,PassportExp =@PassportExp

				,ChineseName=@ChineseName
				,PlaceOfbirth =@PlaceOfbirth
				,Ethnic =@Ethnic 
				,[Native] =@Native 
				,Religion =@Religion 
				,DateOfIDCard =@DateOfIDCard 
				,PlaceOfIDCard =@PlaceOfIDCard 
				,HomePhone =@HomePhone 
				,Qualification =@Qualification 
				,Major =@Major 
			WHERE EmpId =@EmpId
	
			UPDATE [dbo].[EmployeeSummary] WITH(ROWLOCK)
						   SET CountryCode = @CountryCode
			WHERE [EmpId]=@EmpId

			COMMIT TRANSACTION;
		SELECT @ErrCode=0,@ErrCode=''
	END TRY
	BEGIN CATCH
		ROLLBACK TRANSACTION
		SELECT @ErrCode=100,@ErrMsg=N'Update failed';
	END CATCH
END
