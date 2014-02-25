USE [HRM_SMS]
GO
/****** Object:  StoredProcedure [dbo].[Employee_Summary_Update]    Script Date: 2013-10-29 4:21:15 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Employee_Contract_Update] 
	@EmpID Int
    ,@BankAccount nvarchar(100)=NULL
    ,@TaxCode nvarchar(150)=NULL
    ,@SocialInsuranceNo nvarchar(150)=NULL
    ,@RegisteredHospital nvarchar(250)=NULL
    ,@Contract1 tinyint=NULL
    ,@FromDate1 datetime=NULL
    ,@ToDate1 datetime=NULL
    ,@Contract2 tinyint=NULL
    ,@FromDate2 datetime=NULL
    ,@ToDate2 datetime=NULL
    ,@Contract3 tinyint=NULL
    ,@FromDate3 datetime=NULL
    ,@ToDate3 datetime=NULL
    ,@Contract4 tinyint=NULL
    ,@FromDate4 datetime=NULL
    ,@ToDate4 datetime=NULL
    ,@Contract5 tinyint=NULL
    ,@FromDate5 datetime=NULL
    ,@ToDate5 datetime=NULL
	,@History nvarchar(500)=NULL

	,@ErrCode int = 0 OUTPUT
	,@ErrMsg varchar(200) = '' OUTPUT	
AS
/*
Created: TOM@2013-10-01
Task: Update data of an employee Contract 
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/

BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
		BEGIN TRANSACTION;
			UPDATE [dbo].[EmployeeContract] WITH(ROWLOCK)
			   SET [BankAccount] = @BankAccount
				   ,[TaxCode] = @TaxCode
				   ,[SocialInsuranceNo] = @SocialInsuranceNo
				   ,[RegisteredHospital]= @RegisteredHospital 
				   ,[Contract1]= @Contract1 
				   ,[FromDate1]= @FromDate1 
				   ,[ToDate1]= @ToDate1 
				   ,[Contract2]= @Contract2
				   ,[FromDate2]= @FromDate2 
				   ,[ToDate2]= @ToDate2
				   ,[Contract3]= @Contract3
				   ,[FromDate3]= @FromDate3 
				   ,[ToDate3]= @ToDate3
				   ,[Contract4]= @Contract4
				   ,[FromDate4]= @FromDate4 
				   ,[ToDate4]= @ToDate4
				   ,[Contract5]= @Contract5
				   ,[FromDate5]= @FromDate5 
				   ,[ToDate5]= @ToDate5 
				   ,[History] = @History
			 WHERE [EmpId]=@EmpId
		COMMIT TRANSACTION;
		SELECT @ErrCode=0,@ErrCode=''
	END TRY
	BEGIN CATCH
		ROLLBACK TRANSACTION
		SELECT @ErrCode=100,@ErrMsg=N'Update failed';
	END CATCH

END