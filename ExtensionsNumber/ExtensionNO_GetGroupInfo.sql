USE [HRM_SMS]
GO
/****** Object:  StoredProcedure [dbo].[EmployeeSupervisor_GetListSupervisorByEmpID]    Script Date: 2013-10-29 4:22:12 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[ExtensionNO_GetGroupInfo]
	@isInternal BIT = NULL,
	@GroupID INT = NULL
AS
/*
Created: Tom.Vo@2014-01-04
Task: Get list group Extensions Number
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
SET NOCOUNT ON
IF @isInternal IS NULL
	SELECT exg.[ExtID]
		  ,COALESCE(g.[GroupID],exg.[ExtID]) TeamID		
		  ,ISNULL(g.Code,'') Team
		  ,COALESCE(g.Name,exg.[FullName]) TeamName
		  ,SUM(CASE WHEN exm.[ExtID] IS NOT NULL THEN 1 ELSE 0 END ) TotalMember
		  ,exg.IsInternal
		  ,exg.[OrderNo] 
	  FROM [dbo].[ExtensionNumbers] exg WITH(NOLOCK)
		LEFT JOIN dbo.[Group] g WITH(NOLOCK)
			ON exg.GroupID = g.GroupID AND exg.IsInternal = 1 AND exg.IsGroup =1
		LEFT JOIN dbo.ExtensionNumbers exm WITH(NOLOCK)
			ON exm.IsGroup = 0 AND (
				(exg.GroupID  = exm.GroupID AND exm.IsInternal = 1)
				OR (exg.[ExtID]  = exm.GroupID AND exm.IsInternal = 0)
			)
	 WHERE exg.IsGroup =1 
	 GROUP BY exg.[ExtID]
		  ,COALESCE(g.[GroupID],exg.[ExtID])
		  ,ISNULL(g.Code,'') 
		  ,COALESCE(g.Name,exg.[FullName])
		  ,exg.IsInternal
		  ,exg.[OrderNo] 
		  	 
 ELSE IF @GroupID IS NULL
	SELECT exg.[ExtID]
		  ,COALESCE(g.[GroupID],exg.[ExtID]) TeamID		
		  ,ISNULL(g.Code,'') Team
		  ,COALESCE(g.Name,exg.[FullName]) TeamName
		  ,SUM(CASE WHEN exm.[ExtID] IS NOT NULL THEN 1 ELSE 0 END ) TotalMember
		  ,exg.IsInternal
		  ,exg.[OrderNo] 
	  FROM [dbo].[ExtensionNumbers] exg WITH(NOLOCK)
		LEFT JOIN dbo.[Group] g WITH(NOLOCK)
			ON exg.GroupID = g.GroupID AND exg.IsInternal = 1 
		LEFT JOIN dbo.ExtensionNumbers exm WITH(NOLOCK)
			ON exm.IsGroup = 0 AND (
				(exg.GroupID  = exm.GroupID AND exm.IsInternal = 1)
				OR (exg.[ExtID]  = exm.GroupID AND exm.IsInternal = 0)
			)
	 WHERE exg.IsGroup =1 AND 
			@isInternal =  exg.IsInternal
	GROUP BY exg.[ExtID]
		  ,COALESCE(g.[GroupID],exg.[ExtID]) 
		  ,ISNULL(g.Code,'') 
		  ,COALESCE(g.Name,exg.[FullName]) 
		  ,exg.IsInternal
		  ,exg.[OrderNo] 	 
 ELSE IF @GroupID IS NOT NULL
	SELECT exg.[ExtID]
		  ,COALESCE(g.[GroupID],exg.[ExtID]) TeamID		
		  ,ISNULL(g.Code,'') Team
		  ,COALESCE(g.Name,exg.[FullName]) TeamName
		  ,SUM(CASE WHEN exm.[ExtID] IS NOT NULL THEN 1 ELSE 0 END ) TotalMember
		  ,exg.IsInternal
		  ,exg.[OrderNo] 
	  FROM [dbo].[ExtensionNumbers] exg WITH(NOLOCK)
		LEFT JOIN dbo.[Group] g WITH(NOLOCK)
			ON exg.GroupID = g.GroupID AND exg.IsInternal = 1 
		LEFT JOIN dbo.ExtensionNumbers exm WITH(NOLOCK)
			ON exm.IsGroup = 0 AND (
				(exg.GroupID  = exm.GroupID AND exm.IsInternal = 1)
				OR (exg.[ExtID]  = exm.GroupID AND exm.IsInternal = 0)
			)
	 WHERE exg.IsGroup =1 AND 
			@isInternal =  exg.IsInternal AND 
			@GroupID = CASE WHEN @isInternal = 1 THEN exg.[GroupID]
							WHEN @isInternal = 0 THEN exg.[ExtID]
							END
	GROUP BY exg.[ExtID]
		  ,COALESCE(g.[GroupID],exg.[ExtID]) 
		  ,ISNULL(g.Code,'') 
		  ,COALESCE(g.Name,exg.[FullName]) 
		  ,exg.IsInternal
		  ,exg.[OrderNo] 