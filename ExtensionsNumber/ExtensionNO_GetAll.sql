USE [HRM_SMS]
GO
/****** Object:  StoredProcedure [dbo].[EmployeeSupervisor_GetListSupervisorByEmpID]    Script Date: 2013-10-29 4:22:12 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[ExtensionNO_GetAll]
AS
/*
Created: Tom.Vo@2014-01-04
Task: Get list Extensions Number
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
SET NOCOUNT ON
SELECT * FROM 
	(SELECT exg.[ExtID]
		  ,COALESCE(g.[GroupID],exg.[ExtID]) TeamID		
		  ,ISNULL(g.Code,'') Team
		  ,COALESCE(g.Name,exg.[FullName]) TeamName
		  ,COALESCE(ee.EmpID,exm_1.EmpID,NULL) EmpID
		  ,COALESCE(ee.FullName,exm_1.FullName,exm_2.FullName) FullName
		  ,COALESCE(ee.NickName,exm_1.NickName,exm_2.NickName) NickName
		  ,COALESCE(exm_1.ExtensionNo,exm_2.ExtensionNo) [ExtensionNo]
		  ,COALESCE(exm_1.ExtID,exm_2.ExtID) EmpExtID
		  ,exg.IsInternal
		  ,exg.[OrderNo] [OrderNoGroup]
		  ,ROW_NUMBER() OVER(ORDER BY exg.[ExtID]) AS [OrderNoMember]
	  FROM [dbo].[ExtensionNumbers] exg WITH(NOLOCK)
		LEFT JOIN dbo.[Group] g WITH(NOLOCK)
			ON exg.GroupID = g.GroupID AND exg.IsInternal = 1 AND exg.IsGroup =1
		LEFT JOIN [dbo].[ExtensionNumbers] exm_1 WITH(NOLOCK)
			ON exg.GroupID = exm_1.GroupID AND exg.IsInternal = 1 AND exm_1.IsGroup =0 AND exg.IsGroup =1
		LEFT JOIN [dbo].Employee ee WITH(NOLOCK)
			ON exm_1.EmpID = ee.EmpID 
		LEFT JOIN [dbo].[ExtensionNumbers] exm_2 WITH(NOLOCK)
			ON exg.ExtID = exm_2.GroupID AND exg.IsInternal = 0 AND exm_2.IsGroup =0 AND exg.IsGroup =1
	 WHERE COALESCE(ee.EmpID,exm_1.EmpID,exm_2.EmpID,-1)> 0 OR (exg.IsInternal = 0 AND  exg.IsGroup =1 )
	) TBL
	WHERE EmpExtID IS NOT NULL
 ORDER BY [OrderNoGroup],[OrderNoMember]