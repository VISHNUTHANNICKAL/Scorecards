




create or replace PACKAGE BODY SCORECARD AS 
 PROCEDURE SP_GET_ERM_SCORECARD (
    vfusionid in VARCHAR2,period in DATE,p_result OUT SYS_REFCURSOR) IS
        v_MaxStar  number;
        v_MaxQaQc  number;
        v_MinTat number;
        v_MinAht number;
        v_MaxAdh number;
    BEGIN
        
        SELECT MAX(AVG(B.STAR_RATING)) into v_MaxStar
        FROM ASIT_ROSTER_TABLE A
        LEFT JOIN asit_star_rating B ON A.FUSIONID = B.EMPLOYEE_CUSTOM_ID
        WHERE A.DEPT IN ('ERM') 
        --and A.FUSIONID = '101687'
        AND B.MONTH > =   trunc(period,'MONTH')
        AND B.MONTH < =   LAST_DAY(period)
        GROUP BY B.MONTH,A.FUSIONID,A.UCID,A.DEPT;

        SELECT MAX(AVG(B.MTD_SCORES)*100) into v_MaxQaQc
            FROM ASIT_ROSTER_TABLE A
            LEFT JOIN asit_icw_qaqc B ON A.FUSIONID = B.FUSION_ID
            WHERE A.DEPT IN ('ERM') 
            --and A.FUSIONID = '101687'
            AND B.MONTH > =   trunc(period,'MONTH')
        AND B.MONTH < =   LAST_DAY(period)
            GROUP BY B.MONTH,A.FUSIONID,A.UCID,A.DEPT;
            
            SELECT MIN(AVG(B.MTD_TAT)) into v_MinTat
        FROM ASIT_ROSTER_TABLE A
        LEFT JOIN asit_icw_TAT B ON A.FUSIONID = B.FUSIONID
        WHERE A.DEPT IN ('ERM')
        AND B.MONTH > =   trunc(period,'MONTH')
        AND B.MONTH < =   LAST_DAY(period)
        GROUP BY B.MONTH,A.FUSIONID,A.UCID,B.UPDATE_AT,A.DEPT;

        SELECT MIN(AVG(D.IB_AHT)) into v_MinAht
        FROM ASIT_ROSTER_TABLE A
        LEFT JOIN ASIT_TELEPHONY D ON A.FUSIONID = D.FUSION_ID
        WHERE A.DEPT IN ('ERM')
        and D.IB_AHT > 0
        AND D.MONTH > =  trunc(period,'MONTH')
            AND D.MONTH < =  LAST_DAY(period)
        GROUP BY D.MONTH,A.FUSIONID,A.UCID,A.DEPT;
        
        SELECT MAX(AVG(D.ADHERENCE_PERCENTAGE)*100) into v_MaxAdh
        FROM ASIT_ROSTER_TABLE A
        LEFT JOIN ASIT_TELEPHONY D ON A.FUSIONID = D.FUSION_ID
        WHERE A.DEPT IN ('ERM')
        AND D.MONTH > =  trunc(period,'MONTH')
            AND D.MONTH < =  LAST_DAY(period)
        GROUP BY D.MONTH,A.FUSIONID,A.UCID,A.DEPT;

         if(vfusionid is null ) then
            OPEN p_result FOR  
            
            select x.fusionid, ROUND(avg(QA_SCORE),2) as QA_SCORE
            ,case when avg(QA_SCORE)> 99 then 20
                 when avg(QA_SCORE) between 95 and 99  then 15
                 when avg(QA_SCORE) between 90 and 95  then 10
                 else 0
            end as QA_Points
            ,ROUND(avg(y.STAR_RATING),2) as STAR_RATING
            ,ROUND((avg(y.STAR_RATING)/v_MaxStar)*20,2) as STAR_RATING_POINTS
            ,ROUND(avg(z.QAQC_SCORE),2) as ICW_QAQC_SCORE
            ,case when avg(z.QAQC_SCORE) > 90 then ROUND(avg(z.QAQC_SCORE)/v_MaxQaQc *12,2)
            else 0 end as QAQC_POINTS
            ,ROUND(avg(tat.iCW_TAT),2) as ICW_TAT
            ,case when avg(tat.iCW_TAT) = v_MinTat then 20
                else ROUND((0.1/avg(tat.iCW_TAT))*20,2) end as TAT_POINTS
                ,ROUND(avg(aht.IB_AHT),2) as IB_AHT
                ,ROUND((v_MinAht/avg(aht.IB_AHT))*12,2) as AHT_POINTS
                ,ROUND(avg(adh.ADHERENCE),2) as ADHERENCE
            ,ROUND(avg(adh.ADHERENCE)/v_maxadh*10,2) as ADHERENCE_POINTS
            from
            (
                SELECT TO_CHAR(B.ROSTER_MONTH, 'Mon yyyy')
                ,A.FUSIONID,A.UCID,A.DEPT,
                AVG(B.SCORE) AS QA_SCORE
                FROM ASIT_ROSTER_TABLE A
                LEFT JOIN asit_quality B ON A.FUSIONID = B.FUSION_ID
                WHERE A.DEPT IN ('ERM') 
                --and A.FUSIONID = vfusionid
                AND B.ROSTER_MONTH >=  trunc(period,'MONTH')
                and B.ROSTER_MONTH <=   LAST_DAY(period)
                GROUP BY B.ROSTER_MONTH,A.FUSIONID,A.UCID,A.DEPT
            ) x
            left join
            (
                SELECT TO_CHAR(B.MONTH, 'Mon yyyy')
                ,A.FUSIONID,A.UCID,A.DEPT,
                AVG(B.STAR_RATING) AS STAR_RATING
                FROM ASIT_ROSTER_TABLE A
                LEFT JOIN asit_star_rating B ON A.FUSIONID = B.EMPLOYEE_CUSTOM_ID
                WHERE A.DEPT IN ('ERM') 
                --and A.FUSIONID = vfusionid
                AND B.MONTH >=  trunc(period,'MONTH')
                and B.MONTH <=   LAST_DAY(period)
                GROUP BY B.MONTH,A.FUSIONID,A.UCID,A.DEPT
            ) y
            on x.FUSIONID = y.FUSIONID
            left join
            (
                SELECT TO_CHAR(B.MONTH, 'Mon yyyy')
                ,A.FUSIONID,A.UCID,A.DEPT,
                AVG(B.MTD_SCORES)*100 AS QAQC_SCORE
                FROM ASIT_ROSTER_TABLE A
                LEFT JOIN asit_icw_qaqc B ON A.FUSIONID = B.FUSION_ID
                WHERE A.DEPT IN ('ERM') 
                -- and A.FUSIONID = '101687'
                AND B.MONTH >=  trunc(period,'MONTH')
                and B.MONTH <=   LAST_DAY(period)
                GROUP BY B.MONTH,A.FUSIONID,A.UCID,A.DEPT
            ) z
            on x.FUSIONID=Z.FUSIONID
            left join
            (
                SELECT TO_CHAR(B.MONTH, 'Mon yyyy')
                ,A.FUSIONID,A.UCID,B.UPDATE_AT,A.DEPT,
                AVG(B.MTD_TAT) AS iCW_TAT
                FROM ASIT_ROSTER_TABLE A
                LEFT JOIN asit_icw_TAT B ON A.FUSIONID = B.FUSIONID
                WHERE A.DEPT IN ('ERM')
                AND B.MONTH >=  trunc(period,'MONTH')
                and B.MONTH <=   LAST_DAY(period)
                GROUP BY B.MONTH,A.FUSIONID,A.UCID,B.UPDATE_AT,A.DEPT
            ) tat
            on x.FUSIONID=tat.FUSIONID
             left join
            (
                SELECT TO_CHAR(D.MONTH, 'Mon yyyy')
                ,A.FUSIONID,A.UCID,A.DEPT,
                AVG(D.IB_AHT) AS IB_AHT
                FROM ASIT_ROSTER_TABLE A
                LEFT JOIN ASIT_TELEPHONY D ON A.FUSIONID = D.FUSION_ID
                WHERE A.DEPT IN ('ERM')
                and D.IB_AHT > 0
                --and A.FUSIONID = vfusionid
                AND D.MONTH >=  trunc(period,'MONTH')
                    AND D.MONTH <=   LAST_DAY(period)
                GROUP BY D.MONTH,A.FUSIONID,A.UCID,A.DEPT
            ) aht
             on x.FUSIONID=aht.FUSIONID
            left join
             (
                 SELECT TO_CHAR(D.MONTH, 'Mon yyyy')
                ,A.FUSIONID,A.UCID,A.DEPT,
                AVG(D.ADHERENCE_PERCENTAGE) *100 AS ADHERENCE,
                DENSE_RANK() OVER(PARTITION BY D.MONTH,A.DEPT ORDER BY AVG(D.ADHERENCE_PERCENTAGE) DESC) ADHERENCE_Rank
                FROM ASIT_ROSTER_TABLE A
                LEFT JOIN ASIT_TELEPHONY D ON A.FUSIONID = D.FUSION_ID
                WHERE A.DEPT IN ('ERM')
                AND D.MONTH > =  trunc(period,'MONTH')
                    AND D.MONTH <=   LAST_DAY(period)
                GROUP BY D.MONTH,A.FUSIONID,A.UCID,A.DEPT
             ) adh
             on x.FUSIONID=adh.FUSIONID
             group by x.fusionid;
        else
            OPEN p_result FOR  
            
            select x.fusionid, ROUND(avg(QA_SCORE),2) as QA_SCORE
            ,case when avg(QA_SCORE)> 99 then 20
                 when avg(QA_SCORE) between 95 and 99  then 15
                 when avg(QA_SCORE) between 90 and 95  then 10
                 else 0
            end as QA_Points,ROUND(avg(y.STAR_RATING),2) as STAR_RATING
            ,ROUND((avg(y.STAR_RATING)/v_MaxStar)*20,2) as STAR_RATING_POINTS
            ,ROUND(avg(z.QAQC_SCORE),2) as ICW_QAQC_SCORE
            ,case when avg(z.QAQC_SCORE) > 90 then ROUND(avg(z.QAQC_SCORE)/v_MaxQaQc *12,2)
            else 0 end as QAQC_POINTS
            ,ROUND(avg(tat.iCW_TAT),2) as ICW_TAT
            ,case when avg(tat.iCW_TAT) = v_MinTat then 20
                else ROUND((0.1/avg(tat.iCW_TAT))*20,2) end as TAT_POINTS
            ,ROUND(avg(aht.IB_AHT),2) as IB_AHT
            ,ROUND((v_MinAht/avg(aht.IB_AHT))*12,2) as AHT_POINTS
            ,ROUND(avg(adh.ADHERENCE),2) as ADHERENCE
            ,ROUND(avg(adh.ADHERENCE)/v_maxadh*10,2) as ADHERENCE_POINTS
            from(
            SELECT TO_CHAR(B.ROSTER_MONTH, 'Mon yyyy')
            ,A.FUSIONID,A.UCID,A.DEPT,
            AVG(B.SCORE) AS QA_SCORE
            FROM ASIT_ROSTER_TABLE A
            LEFT JOIN asit_quality B ON A.FUSIONID = B.FUSION_ID
            WHERE A.DEPT IN ('ERM') 
            and A.FUSIONID = vfusionid
            AND B.ROSTER_MONTH >=  trunc(period,'MONTH')
            and B.ROSTER_MONTH <=   LAST_DAY(period)
            GROUP BY B.ROSTER_MONTH,A.FUSIONID,A.UCID,A.DEPT
            ) x
            join
            (
            SELECT TO_CHAR(B.MONTH, 'Mon yyyy')
            ,A.FUSIONID,A.UCID,A.DEPT,
                AVG(B.STAR_RATING) AS STAR_RATING
                FROM ASIT_ROSTER_TABLE A
                LEFT JOIN asit_star_rating B ON A.FUSIONID = B.EMPLOYEE_CUSTOM_ID
                WHERE A.DEPT IN ('ERM') 
                and A.FUSIONID = vfusionid
                            AND B.MONTH >=  trunc(period,'MONTH')
                            and B.MONTH <=   LAST_DAY(period)
                GROUP BY B.MONTH,A.FUSIONID,A.UCID,A.DEPT) y
                on x.FUSIONID = y.FUSIONID
            join
            (
                SELECT TO_CHAR(B.MONTH, 'Mon yyyy')
                ,A.FUSIONID,A.UCID,A.DEPT,
                AVG(B.MTD_SCORES)*100 AS QAQC_SCORE
                FROM ASIT_ROSTER_TABLE A
                LEFT JOIN asit_icw_qaqc B ON A.FUSIONID = B.FUSION_ID
                WHERE A.DEPT IN ('ERM') 
               and A.FUSIONID = vfusionid
               AND B.MONTH >=  trunc(period,'MONTH')
                and B.MONTH <=   LAST_DAY(period)
                GROUP BY B.MONTH,A.FUSIONID,A.UCID,A.DEPT
                ) z
            on x.FUSIONID=Z.FUSIONID
              join
            (
                SELECT TO_CHAR(B.MONTH, 'Mon yyyy')
                ,A.FUSIONID,A.UCID,B.UPDATE_AT,A.DEPT,
                AVG(B.MTD_TAT) AS iCW_TAT
                FROM ASIT_ROSTER_TABLE A
                LEFT JOIN asit_icw_TAT B ON A.FUSIONID = B.FUSIONID
                WHERE A.DEPT IN ('ERM')
                and A.FUSIONID = vfusionid
                AND B.MONTH >=  trunc(period,'MONTH')
                and B.MONTH <=   LAST_DAY(period)
                GROUP BY B.MONTH,A.FUSIONID,A.UCID,B.UPDATE_AT,A.DEPT
            ) tat
            on x.FUSIONID=tat.FUSIONID
            join
            (
                SELECT TO_CHAR(D.MONTH, 'Mon yyyy')
                ,A.FUSIONID,A.UCID,A.DEPT,
                AVG(D.IB_AHT) AS IB_AHT
                FROM ASIT_ROSTER_TABLE A
                LEFT JOIN ASIT_TELEPHONY D ON A.FUSIONID = D.FUSION_ID
                WHERE A.DEPT IN ('ERM')
                and D.IB_AHT > 0
                and A.FUSIONID = vfusionid
                AND D.MONTH >=  trunc(period,'MONTH')
                    AND D.MONTH <=   LAST_DAY(period)
                GROUP BY D.MONTH,A.FUSIONID,A.UCID,A.DEPT
            ) aht
             on x.FUSIONID=aht.FUSIONID
             join
             (
                 SELECT TO_CHAR(D.MONTH, 'Mon yyyy')
                ,A.FUSIONID,A.UCID,A.DEPT,
                AVG(D.ADHERENCE_PERCENTAGE) *100 AS ADHERENCE,
                DENSE_RANK() OVER(PARTITION BY D.MONTH,A.DEPT ORDER BY AVG(D.ADHERENCE_PERCENTAGE) DESC) ADHERENCE_Rank
                FROM ASIT_ROSTER_TABLE A
                LEFT JOIN ASIT_TELEPHONY D ON A.FUSIONID = D.FUSION_ID
                WHERE A.DEPT IN ('ERM')
                and A.FUSIONID = vfusionid
                AND D.MONTH > =  trunc(period,'MONTH')
                    AND D.MONTH <=   LAST_DAY(period)
                GROUP BY D.MONTH,A.FUSIONID,A.UCID,A.DEPT
             ) adh
             on x.FUSIONID=adh.FUSIONID
            group by x.fusionid;
        end if;
   END SP_GET_ERM_SCORECARD;
   
   


  PROCEDURE CR_SC_MTD_AGNTS (
    per in VARCHAR2,vfusionid in VARCHAR2, p_result OUT SYS_REFCURSOR) 
    is 
    period date;
  BEGIN
    -- TODO: Implementation required for PROCEDURE CR_SC_MTD_AGNTS.CR_SC_MTD_AGNTS
      period:=to_date(per,'yyyy-MM-dd');
      --vfusionid:='196035';
         dbms_output.put_line('period =' || period);
         
         if(vfusionid is null and period is null ) then
            OPEN p_result FOR  
 select 
to_char("MONTH",'MON-YY') MONTH,
"UCID",
"EMPLOYEE ID",
"NAME",
"Team Lead",
"LOCATION",
"DEPT",
"Global Rank",
"Total Points",
"Credit Per Hr",
"Credit Rank",
"Credits Score",
"CPH_TARGET",
"Quality Score",
"Quality Rank",
"Quality_Score",
"QUALITY_TARGET",
"Stella Star Rating",
"Stella Star Rank",
"Stella Star Score",
"STAR_TARGET",
"Schedule Adherence",
"Adherence Rank",
"Adherence Score",
"ADHERENCE_TARGET",
"Inbound AHT",
"AHT Rank",
"AHT Score",
"IB_AHT_TARGET",
"Cms Defect %",
"Cms Defect Rank",
"Cms Defect Score",
"CMS_DEFECT_TARGET",
"Out Of",
"YTD Global Rank",
"YTD Global Total Points"
--,sn
from ( 
 select 
b."MONTH",
b."UCID",
b."EMPLOYEE ID",
b."NAME",
b."Team Lead",
b."LOCATION",
b."DEPT",
b."Overall Rank" "Global Rank",
b."Overall Score" "Total Points",
b."Credit Per Hr",
b."Credit Rank",
b."Credits Score",
b."CPH_TARGET",
b."Quality Score",
b."Quality Rank",
b."Quality_Score",
b."QUALITY_TARGET",
b."Stella Star Rating",
b."Stella Star Rank",
b."Stella Star Score",
b."STAR_TARGET",
b."Schedule Adherence",
b."Adherence Rank",
b."Adherence Score",
b."ADHERENCE_TARGET",
b."Inbound AHT",
b."AHT Rank",
b."AHT Score",
b."IB_AHT_TARGET",
b."Cms Defect %",
b."Cms Defect Rank",
b."Cms Defect Score",
b."CMS_DEFECT_TARGET",
b."Out Of",
b."Global Rank" "YTD Global Rank",
b."Global Total Points" "YTD Global Total Points"
,row_number() over (Partition by  b."Overall Rank" order by b."NAME" asc,  b."Overall Rank") sn
from(
select 
a.month  ,a.ucid,a."EMPLOYEE ID",a.name,a."Team Lead",a.location,a.dept
,rank() OVER (PARTITION by a.month,a.dept ORDER BY
(coalesce(a."Credits Score",0)+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+coalesce(a."Adherence Score",0)+coalesce(a."AHT Score",0)
+coalesce(a."Cms Defect Score",0)) desc,a.dept,a.month ) "Overall Rank"
,(coalesce(a."Credits Score",0)+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+coalesce(a."Adherence Score",0)+coalesce(a."AHT Score",0)
+coalesce(a."Cms Defect Score",0)) "Overall Score"
,a."Credit Per Hr",a."Credit Rank",a."Credits Score",a.CPH_TARGET
, a."Quality Score" 
,case when a."Quality Rank" is null then 1 else a."Quality Rank" end as "Quality Rank"
,coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0) as "Quality_Score",a.QUALITY_TARGET
,a."Stella Star Rating" 
,case when a."Stella Star Rank" is null then 1 else a."Stella Star Rank" end as "Stella Star Rank"
,coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0) as "Stella Star Score",a.STAR_TARGET
,a."Schedule Adherence",a."Adherence Rank",a."Adherence Score",a.ADHERENCE_TARGET
,a."Inbound AHT",a."AHT Rank",a."AHT Score",a.IB_AHT_TARGET
,a."Cms Defect %",a."Cms Defect Rank",a."Cms Defect Score",a.CMS_DEFECT_TARGET
,a."Out Of"
,b."Global Rank"
,b."Global Total Points"
from
(
select 
last_day(a.month) month,
a.ucid,
a.fusionid "EMPLOYEE ID",
a.name,
a.team_leader "Team Lead",
a.location,
a.dept
--,rank() OVER (PARTITION by last_day(a.month),a.dept ORDER BY (coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0)) desc,a.dept,last_day(a.month) ) "Global Rank"
--,(coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0))  "Total Points"
,b."Credit Per Hr",b."Credit Rank",b."Credits Score",
--b.CPH_TARGET
i.CPH_TARGET
,c."Quality Score",c."Quality Rank",c."Quality_Score"
,i.QUALITY_TARGET
,d."Stella Star Rating",d."Stella Star Rank",d."Stella Star Score"
,i.STAR_TARGET
,e."Schedule Adherence",e."Adherence Rank",e."Adherence Score"
,i.ADHERENCE_TARGET
,f."Inbound AHT",f."AHT Rank",f."AHT Score"
,i.IB_AHT_TARGET
,g."Cms Defect %",g."Cms Defect Rank",g."Cms Defect Score"
,i.CMS_DEFECT_TARGET
,h."Out Of"
from asit_roster_table a
left join(
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
--,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
,"CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
,e."CPH_TARGET"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
left join(
select month,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95","CPH_TARGET"
from (
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of"
)a )b
where "CPH_TARGET" is not null)e on last_day(a.rpt_month)=last_day(e.month) and c.dept=e.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of",e."CPH_TARGET"
)a
) b on last_day(a.month)=last_day(b.month) and a.fusionid=b.fusionid
left join(
select last_day(roster_month) month,
a.fusion_id,c.ucid,a.employee_name,c.dept
,coalesce(round(avg(score),2),0) "Quality Score"
,rank() OVER (PARTITION by last_day(roster_month),c.dept ORDER BY coalesce(round(avg(score),2),0) desc,c.dept,last_day(roster_month) )  "Quality Rank"
,b."Out Of"
,case 
when coalesce(round(avg(score),2),0) >=97.50  then 3.75 
when coalesce(round(avg(score),2),0) >=95.20  then 2.5
when coalesce(round(avg(score),2),0) >=90  then 1.25 
else 0
end as
"Quality_Score"
from asit_quality a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.roster_month)=c.month and a.fusion_id=c.fusionid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.roster_month)=b.monthn and b.dept=c.dept
--where a.roster_month=last_day('31-JAN-24') 
--and a.ucid in (select distinct ucid from asit_roster_table where fusionid='105554' ) 
group by last_day(roster_month),a.fusion_id,c.ucid,a.employee_name,c.dept,b."Out Of"

)c on last_day(a.month)=last_day(c.month) and a.fusionid=c.fusion_id
left join(
select 
last_day(a.month) month,a.employee_custom_id,c.dept
--,a.team_leader
,coalesce(round(avg(star_rating),2),0) "Stella Star Rating"
,rank() OVER (PARTITION by last_day(a.month),c.dept  ORDER BY coalesce(round(avg(star_rating),2),0) desc,c.dept ,last_day(a.month) ) "Stella Star Rank"
,b."Out Of"
,case when coalesce(round(avg(star_rating),2),0) >= 4.6 then 4.00
when coalesce(round(avg(star_rating),2),0) >= 4.5 then 3.00 
when coalesce(round(avg(star_rating),2),0) >= 4.4 then 2.00
when coalesce(round(avg(star_rating),2),0) >= 4.3 then 1.00
else 0
end as "Stella Star Score"
from asit_star_rating a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.employee_custom_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
--where  a.month=last_day(a.month)
--and employee_custom_id in ('196400') 
group by last_day(a.month),c.dept,a.employee_custom_id,b."Out Of"
)d on last_day(a.month)=last_day(d.month) and a.fusionid=d.employee_custom_id
left join (
select 
last_day(a.month) month,a.fusion_id,c.dept 
,coalesce(round(adherence_percentage*100,2),0) "Schedule Adherence"
,rank() OVER (PARTITION by last_day(a.month),c.dept ORDER BY coalesce(round(adherence_percentage*100,2),0) desc,c.dept ,last_day(a.month) ) "Adherence Rank"
,b."Out Of"
,case when coalesce(round(adherence_percentage*100,2),0) >=95 then 4.00 
when coalesce(round(adherence_percentage*100,2),0) >=92.5 then 3.00
when coalesce(round(adherence_percentage*100,2),0) >=90 then 2.00 
when coalesce(round(adherence_percentage*100,2),0) >=87.5 then 1.00
else 0
end as
"Adherence Score"
from asit_telephony a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.fusion_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)e on last_day(a.month)=last_day(e.month) and a.fusionid=e.fusion_id
left join (
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
)f on to_char(last_day(a.month),'MON-YY')=f.month and a.fusionid=f.fusionid
left join(
select 
last_day(a.month) month,c.fusionid,a.ucid,c.dept,a.cms_defect_percentage,coalesce(round(a.cms_defect_percentage*100,2),0) "Cms Defect %"
,rank() OVER (PARTITION by a.month ORDER BY coalesce(round(a.cms_defect_percentage*100,2),0) asc,a.month ) "Cms Defect Rank"
,b."Out Of"
,case when coalesce(round(a.cms_defect_percentage*100,2),0) <0.5 then 18.5 
when coalesce(round(a.cms_defect_percentage*100,2),0) <1 then 12.5
when coalesce(round(a.cms_defect_percentage*100,2),0) <=1.5 then 6.25
else 0
end as
"Cms Defect Score"
from asit_cms_defect a
join(
select month,fusionid,ucid,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.ucid=c.ucid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)g on last_day(a.month)=g.month and a.fusionid=g.fusionid
left join(
select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)h on last_day(a.month)=h.monthn and a.dept=h.dept
left join CR_SC_AGNTS_TARGET i on last_day(a.month)=i.month and a.dept=i.dept
where --a.month>=last_day(sysdate)and
 a.dept in ('CCC-R','CCC-R SPANISH','FLEX')
and a.location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and a.designation in ('Agent')
and a.final_status='ACTIVE'
and a.team_leader not in (select name from not_teamleader)
)a
left join (
select 
"EMPLOYEE ID"--,name,"Team Lead",location,dept
,rank() OVER (order by sum("Total Points") desc)  "Global Rank"
,sum("Total Points") "Global Total Points"
,avg("Credit Per Hr") "Credit Per Hr",
avg("Quality Score") "Quality Score",avg("Stella Star Rating") "Stella Star Rating",avg("Schedule Adherence") "Schedule Adherence",
avg("Inbound AHT") "Inbound AHT",avg("Cms Defect %") "Cms Defect %"
from
(
select 
to_char(a.month,'MON-YY') month ,a.ucid,a."EMPLOYEE ID",a.name,a."Team Lead",a.location,a.dept
,rank() OVER (PARTITION by a.month,a.dept ORDER BY
(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") desc,a.dept,a.month ) "Global Rank"
,(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") "Total Points"
,coalesce(a."Credit Per Hr",0) "Credit Per Hr" ,a."Credit Rank",a."Credits Score",a.CPH_TARGET
, coalesce (a."Quality Score",0)  "Quality Score"
,case when a."Quality Rank" is null then 1 else a."Quality Rank" end as "Quality Rank"
,coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0) as "Quality_Score",a.QUALITY_TARGET
,coalesce(a."Stella Star Rating",0) "Stella Star Rating"
,case when a."Stella Star Rank" is null then 1 else a."Stella Star Rank" end as "Stella Star Rank"
,coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0) as "Stella Star Score",a.STAR_TARGET
,coalesce(a."Schedule Adherence",0) "Schedule Adherence",a."Adherence Rank",a."Adherence Score",a.ADHERENCE_TARGET
,coalesce(a."Inbound AHT",0) "Inbound AHT",a."AHT Rank",a."AHT Score",a.IB_AHT_TARGET
,coalesce(a."Cms Defect %",0) "Cms Defect %" ,a."Cms Defect Rank",a."Cms Defect Score",a.CMS_DEFECT_TARGET
,a."Out Of"
from
(
select 
last_day(a.month) month,
a.ucid,
a.fusionid "EMPLOYEE ID",
a.name,
a.team_leader "Team Lead",
a.location,
a.dept
--,rank() OVER (PARTITION by last_day(a.month),a.dept ORDER BY (coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0)) desc,a.dept,last_day(a.month) ) "Global Rank"
--,(coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0))  "Total Points"
,b."Credit Per Hr",b."Credit Rank",b."Credits Score",
--b.CPH_TARGET
i.CPH_TARGET
,c."Quality Score",c."Quality Rank",c."Quality_Score"
,i.QUALITY_TARGET
,d."Stella Star Rating",d."Stella Star Rank",d."Stella Star Score"
,i.STAR_TARGET
,e."Schedule Adherence",e."Adherence Rank",e."Adherence Score"
,i.ADHERENCE_TARGET
,f."Inbound AHT",f."AHT Rank",f."AHT Score"
,i.IB_AHT_TARGET
,g."Cms Defect %",g."Cms Defect Rank",g."Cms Defect Score"
,i.CMS_DEFECT_TARGET
,h."Out Of"
from asit_roster_table a
left join(
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
--,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
,"CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
,e."CPH_TARGET"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
left join(
select month,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95","CPH_TARGET"
from (
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of"
)a )b
where "CPH_TARGET" is not null)e on last_day(a.rpt_month)=last_day(e.month) and c.dept=e.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of",e."CPH_TARGET"
)a
) b on last_day(a.month)=last_day(b.month) and a.fusionid=b.fusionid
left join(
select last_day(roster_month) month,
a.fusion_id,c.ucid,a.employee_name,c.dept
,coalesce(round(avg(score),2),0) "Quality Score"
,rank() OVER (PARTITION by last_day(roster_month),c.dept ORDER BY coalesce(round(avg(score),2),0) desc,c.dept,last_day(roster_month) )  "Quality Rank"
,b."Out Of"
,case 
when coalesce(round(avg(score),2),0) >=97.50  then 3.75 
when coalesce(round(avg(score),2),0) >=95.20  then 2.5
when coalesce(round(avg(score),2),0) >=90  then 1.25 
else 0
end as
"Quality_Score"
from asit_quality a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.roster_month)=c.month and a.fusion_id=c.fusionid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.roster_month)=b.monthn and b.dept=c.dept
--where a.roster_month=last_day('31-JAN-24') 
--and a.ucid in (select distinct ucid from asit_roster_table where fusionid='105554' ) 
group by last_day(roster_month),a.fusion_id,c.ucid,a.employee_name,c.dept,b."Out Of"

)c on last_day(a.month)=last_day(c.month) and a.fusionid=c.fusion_id
left join(
select 
last_day(a.month) month,a.employee_custom_id,c.dept
--,a.team_leader
,coalesce(round(avg(star_rating),2),0) "Stella Star Rating"
,rank() OVER (PARTITION by last_day(a.month),c.dept  ORDER BY coalesce(round(avg(star_rating),2),0) desc,c.dept ,last_day(a.month) ) "Stella Star Rank"
,b."Out Of"
,case when coalesce(round(avg(star_rating),2),0) >= 4.6 then 4.00
when coalesce(round(avg(star_rating),2),0) >= 4.5 then 3.00 
when coalesce(round(avg(star_rating),2),0) >= 4.4 then 2.00
when coalesce(round(avg(star_rating),2),0) >= 4.3 then 1.00
else 0
end as "Stella Star Score"
from asit_star_rating a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.employee_custom_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
--where  a.month=last_day(a.month)
--and employee_custom_id in ('196400') 
group by last_day(a.month),c.dept,a.employee_custom_id,b."Out Of"
)d on last_day(a.month)=last_day(d.month) and a.fusionid=d.employee_custom_id
left join (
select 
last_day(a.month) month,a.fusion_id,c.dept 
,coalesce(round(adherence_percentage*100,2),0) "Schedule Adherence"
,rank() OVER (PARTITION by last_day(a.month),c.dept ORDER BY coalesce(round(adherence_percentage*100,2),0) desc,c.dept ,last_day(a.month) ) "Adherence Rank"
,b."Out Of"
,case when coalesce(round(adherence_percentage*100,2),0) >=95 then 4.00 
when coalesce(round(adherence_percentage*100,2),0) >=92.5 then 3.00
when coalesce(round(adherence_percentage*100,2),0) >=90 then 2.00 
when coalesce(round(adherence_percentage*100,2),0) >=87.5 then 1.00
else 0
end as
"Adherence Score"
from asit_telephony a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.fusion_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)e on last_day(a.month)=last_day(e.month) and a.fusionid=e.fusion_id
left join (
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
)f on to_char(last_day(a.month),'MON-YY')=f.month and a.fusionid=f.fusionid
left join(
select 
last_day(a.month) month,c.fusionid,a.ucid,c.dept,a.cms_defect_percentage,coalesce(round(a.cms_defect_percentage*100,2),0) "Cms Defect %"
,rank() OVER (PARTITION by a.month ORDER BY coalesce(round(a.cms_defect_percentage*100,2),0) asc,a.month ) "Cms Defect Rank"
,b."Out Of"
,case when coalesce(round(a.cms_defect_percentage*100,2),0) <0.5 then 18.5 
when coalesce(round(a.cms_defect_percentage*100,2),0) <1 then 12.5
when coalesce(round(a.cms_defect_percentage*100,2),0) <=1.5 then 6.25
else 0
end as
"Cms Defect Score"
from asit_cms_defect a
join(
select month,fusionid,ucid,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.ucid=c.ucid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)g on last_day(a.month)=g.month and a.fusionid=g.fusionid
left join(
select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)h on last_day(a.month)=h.monthn and a.dept=h.dept
left join CR_SC_AGNTS_TARGET i on last_day(a.month)=i.month and a.dept=i.dept
where --a.month>=last_day(sysdate)and
 a.dept in ('CCC-R','CCC-R SPANISH','FLEX')
and a.location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and a.designation in ('Agent')
and a.final_status='ACTIVE'
and a.team_leader not in (select name from not_teamleader)
)a)b
--where  "EMPLOYEE ID" in('197233')
group by "EMPLOYEE ID"

) b on a."EMPLOYEE ID"=b."EMPLOYEE ID"
)b
--where b.month >= last_day('21-Feb-24')
--where b."EMPLOYEE ID" in('103851')
where b."Overall Rank"=1
)b where sn=1
order by b.month,b."NAME"
--to_date(concat('01-',month)) asc
;
        
     elsif (vfusionid is null) then
            OPEN p_result FOR
     
select 
to_char(b."MONTH",'MON-YY') MONTH,
b."UCID",
b."EMPLOYEE ID",
b."NAME",
b."Team Lead",
b."LOCATION",
b."DEPT",
b."Overall Rank" "Global Rank",
b."Overall Score" "Total Points",
b."Credit Per Hr",
b."Credit Rank",
b."Credits Score",
b."CPH_TARGET",
b."Quality Score",
b."Quality Rank",
b."Quality_Score",
b."QUALITY_TARGET",
b."Stella Star Rating",
b."Stella Star Rank",
b."Stella Star Score",
b."STAR_TARGET",
b."Schedule Adherence",
b."Adherence Rank",
b."Adherence Score",
b."ADHERENCE_TARGET",
b."Inbound AHT",
b."AHT Rank",
b."AHT Score",
b."IB_AHT_TARGET",
b."Cms Defect %",
b."Cms Defect Rank",
b."Cms Defect Score",
b."CMS_DEFECT_TARGET",
b."Out Of",
b."Global Rank" "YTD Global Rank",
b."Global Total Points" "YTD Global Total Points"
from(
select 
a.month  ,a.ucid,a."EMPLOYEE ID",a.name,a."Team Lead",a.location,a.dept
,rank() OVER (PARTITION by a.month,a.dept ORDER BY
(coalesce(a."Credits Score",0)+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+coalesce(a."Adherence Score",0)+coalesce(a."AHT Score",0)
+coalesce(a."Cms Defect Score",0)) desc,a.dept,a.month ) "Overall Rank"
,(coalesce(a."Credits Score",0)+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+coalesce(a."Adherence Score",0)+coalesce(a."AHT Score",0)
+coalesce(a."Cms Defect Score",0)) "Overall Score"
,a."Credit Per Hr",a."Credit Rank",a."Credits Score",a.CPH_TARGET
, a."Quality Score" 
,case when a."Quality Rank" is null then 1 else a."Quality Rank" end as "Quality Rank"
,coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0) as "Quality_Score",a.QUALITY_TARGET
,a."Stella Star Rating" 
,case when a."Stella Star Rank" is null then 1 else a."Stella Star Rank" end as "Stella Star Rank"
,coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0) as "Stella Star Score",a.STAR_TARGET
,a."Schedule Adherence",a."Adherence Rank",a."Adherence Score",a.ADHERENCE_TARGET
,a."Inbound AHT",a."AHT Rank",a."AHT Score",a.IB_AHT_TARGET
,a."Cms Defect %",a."Cms Defect Rank",a."Cms Defect Score",a.CMS_DEFECT_TARGET
,a."Out Of"
,b."Global Rank"
,b."Global Total Points"
from
(
select 
last_day(a.month) month,
a.ucid,
a.fusionid "EMPLOYEE ID",
a.name,
a.team_leader "Team Lead",
a.location,
a.dept
--,rank() OVER (PARTITION by last_day(a.month),a.dept ORDER BY (coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0)) desc,a.dept,last_day(a.month) ) "Global Rank"
--,(coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0))  "Total Points"
,b."Credit Per Hr",b."Credit Rank",b."Credits Score",
--b.CPH_TARGET
i.CPH_TARGET
,c."Quality Score",c."Quality Rank",c."Quality_Score"
,i.QUALITY_TARGET
,d."Stella Star Rating",d."Stella Star Rank",d."Stella Star Score"
,i.STAR_TARGET
,e."Schedule Adherence",e."Adherence Rank",e."Adherence Score"
,i.ADHERENCE_TARGET
,f."Inbound AHT",f."AHT Rank",f."AHT Score"
,i.IB_AHT_TARGET
,g."Cms Defect %",g."Cms Defect Rank",g."Cms Defect Score"
,i.CMS_DEFECT_TARGET
,h."Out Of"
from asit_roster_table a
left join(
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
--,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
,"CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
,e."CPH_TARGET"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
left join(
select month,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95","CPH_TARGET"
from (
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of"
)a )b
where "CPH_TARGET" is not null)e on last_day(a.rpt_month)=last_day(e.month) and c.dept=e.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of",e."CPH_TARGET"
)a
) b on last_day(a.month)=last_day(b.month) and a.fusionid=b.fusionid
left join(
select last_day(roster_month) month,
a.fusion_id,c.ucid,a.employee_name,c.dept
,coalesce(round(avg(score),2),0) "Quality Score"
,rank() OVER (PARTITION by last_day(roster_month),c.dept ORDER BY coalesce(round(avg(score),2),0) desc,c.dept,last_day(roster_month) )  "Quality Rank"
,b."Out Of"
,case 
when coalesce(round(avg(score),2),0) >=97.50  then 3.75 
when coalesce(round(avg(score),2),0) >=95.20  then 2.5
when coalesce(round(avg(score),2),0) >=90  then 1.25 
else 0
end as
"Quality_Score"
from asit_quality a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.roster_month)=c.month and a.fusion_id=c.fusionid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.roster_month)=b.monthn and b.dept=c.dept
--where a.roster_month=last_day('31-JAN-24') 
--and a.ucid in (select distinct ucid from asit_roster_table where fusionid='105554' ) 
group by last_day(roster_month),a.fusion_id,c.ucid,a.employee_name,c.dept,b."Out Of"

)c on last_day(a.month)=last_day(c.month) and a.fusionid=c.fusion_id
left join(
select 
last_day(a.month) month,a.employee_custom_id,c.dept
--,a.team_leader
,coalesce(round(avg(star_rating),2),0) "Stella Star Rating"
,rank() OVER (PARTITION by last_day(a.month),c.dept  ORDER BY coalesce(round(avg(star_rating),2),0) desc,c.dept ,last_day(a.month) ) "Stella Star Rank"
,b."Out Of"
,case when coalesce(round(avg(star_rating),2),0) >= 4.6 then 4.00
when coalesce(round(avg(star_rating),2),0) >= 4.5 then 3.00 
when coalesce(round(avg(star_rating),2),0) >= 4.4 then 2.00
when coalesce(round(avg(star_rating),2),0) >= 4.3 then 1.00
else 0
end as "Stella Star Score"
from asit_star_rating a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.employee_custom_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
--where  a.month=last_day(a.month)
--and employee_custom_id in ('196400') 
group by last_day(a.month),c.dept,a.employee_custom_id,b."Out Of"
)d on last_day(a.month)=last_day(d.month) and a.fusionid=d.employee_custom_id
left join (
select 
last_day(a.month) month,a.fusion_id,c.dept 
,coalesce(round(adherence_percentage*100,2),0) "Schedule Adherence"
,rank() OVER (PARTITION by last_day(a.month),c.dept ORDER BY coalesce(round(adherence_percentage*100,2),0) desc,c.dept ,last_day(a.month) ) "Adherence Rank"
,b."Out Of"
,case when coalesce(round(adherence_percentage*100,2),0) >=95 then 4.00 
when coalesce(round(adherence_percentage*100,2),0) >=92.5 then 3.00
when coalesce(round(adherence_percentage*100,2),0) >=90 then 2.00 
when coalesce(round(adherence_percentage*100,2),0) >=87.5 then 1.00
else 0
end as
"Adherence Score"
from asit_telephony a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.fusion_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)e on last_day(a.month)=last_day(e.month) and a.fusionid=e.fusion_id
left join (
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
)f on to_char(last_day(a.month),'MON-YY')=f.month and a.fusionid=f.fusionid
left join(
select 
last_day(a.month) month,c.fusionid,a.ucid,c.dept,a.cms_defect_percentage,coalesce(round(a.cms_defect_percentage*100,2),0) "Cms Defect %"
,rank() OVER (PARTITION by a.month ORDER BY coalesce(round(a.cms_defect_percentage*100,2),0) asc,a.month ) "Cms Defect Rank"
,b."Out Of"
,case when coalesce(round(a.cms_defect_percentage*100,2),0) <0.5 then 18.5 
when coalesce(round(a.cms_defect_percentage*100,2),0) <1 then 12.5
when coalesce(round(a.cms_defect_percentage*100,2),0) <=1.5 then 6.25
else 0
end as
"Cms Defect Score"
from asit_cms_defect a
join(
select month,fusionid,ucid,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.ucid=c.ucid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)g on last_day(a.month)=g.month and a.fusionid=g.fusionid
left join(
select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)h on last_day(a.month)=h.monthn and a.dept=h.dept
left join CR_SC_AGNTS_TARGET i on last_day(a.month)=i.month and a.dept=i.dept
where --a.month>=last_day(sysdate)and
 a.dept in ('CCC-R','CCC-R SPANISH','FLEX')
and a.location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and a.designation in ('Agent')
and a.final_status='ACTIVE'
and a.team_leader not in (select name from not_teamleader)
)a
left join (
select 
"EMPLOYEE ID"--,name,"Team Lead",location,dept
,rank() OVER (order by sum("Total Points") desc)  "Global Rank"
,sum("Total Points") "Global Total Points"
,avg("Credit Per Hr") "Credit Per Hr",
avg("Quality Score") "Quality Score",avg("Stella Star Rating") "Stella Star Rating",avg("Schedule Adherence") "Schedule Adherence",
avg("Inbound AHT") "Inbound AHT",avg("Cms Defect %") "Cms Defect %"
from
(
select 
to_char(a.month,'MON-YY') month ,a.ucid,a."EMPLOYEE ID",a.name,a."Team Lead",a.location,a.dept
,rank() OVER (PARTITION by a.month,a.dept ORDER BY
(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") desc,a.dept,a.month ) "Global Rank"
,(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") "Total Points"
,coalesce(a."Credit Per Hr",0) "Credit Per Hr" ,a."Credit Rank",a."Credits Score",a.CPH_TARGET
, coalesce (a."Quality Score",0)  "Quality Score"
,case when a."Quality Rank" is null then 1 else a."Quality Rank" end as "Quality Rank"
,coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0) as "Quality_Score",a.QUALITY_TARGET
,coalesce(a."Stella Star Rating",0) "Stella Star Rating"
,case when a."Stella Star Rank" is null then 1 else a."Stella Star Rank" end as "Stella Star Rank"
,coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0) as "Stella Star Score",a.STAR_TARGET
,coalesce(a."Schedule Adherence",0) "Schedule Adherence",a."Adherence Rank",a."Adherence Score",a.ADHERENCE_TARGET
,coalesce(a."Inbound AHT",0) "Inbound AHT",a."AHT Rank",a."AHT Score",a.IB_AHT_TARGET
,coalesce(a."Cms Defect %",0) "Cms Defect %" ,a."Cms Defect Rank",a."Cms Defect Score",a.CMS_DEFECT_TARGET
,a."Out Of"
from
(
select 
last_day(a.month) month,
a.ucid,
a.fusionid "EMPLOYEE ID",
a.name,
a.team_leader "Team Lead",
a.location,
a.dept
--,rank() OVER (PARTITION by last_day(a.month),a.dept ORDER BY (coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0)) desc,a.dept,last_day(a.month) ) "Global Rank"
--,(coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0))  "Total Points"
,b."Credit Per Hr",b."Credit Rank",b."Credits Score",
--b.CPH_TARGET
i.CPH_TARGET
,c."Quality Score",c."Quality Rank",c."Quality_Score"
,i.QUALITY_TARGET
,d."Stella Star Rating",d."Stella Star Rank",d."Stella Star Score"
,i.STAR_TARGET
,e."Schedule Adherence",e."Adherence Rank",e."Adherence Score"
,i.ADHERENCE_TARGET
,f."Inbound AHT",f."AHT Rank",f."AHT Score"
,i.IB_AHT_TARGET
,g."Cms Defect %",g."Cms Defect Rank",g."Cms Defect Score"
,i.CMS_DEFECT_TARGET
,h."Out Of"
from asit_roster_table a
left join(
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
--,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
,"CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
,e."CPH_TARGET"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
left join(
select month,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95","CPH_TARGET"
from (
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of"
)a )b
where "CPH_TARGET" is not null)e on last_day(a.rpt_month)=last_day(e.month) and c.dept=e.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of",e."CPH_TARGET"
)a
) b on last_day(a.month)=last_day(b.month) and a.fusionid=b.fusionid
left join(
select last_day(roster_month) month,
a.fusion_id,c.ucid,a.employee_name,c.dept
,coalesce(round(avg(score),2),0) "Quality Score"
,rank() OVER (PARTITION by last_day(roster_month),c.dept ORDER BY coalesce(round(avg(score),2),0) desc,c.dept,last_day(roster_month) )  "Quality Rank"
,b."Out Of"
,case 
when coalesce(round(avg(score),2),0) >=97.50  then 3.75 
when coalesce(round(avg(score),2),0) >=95.20  then 2.5
when coalesce(round(avg(score),2),0) >=90  then 1.25 
else 0
end as
"Quality_Score"
from asit_quality a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.roster_month)=c.month and a.fusion_id=c.fusionid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.roster_month)=b.monthn and b.dept=c.dept
--where a.roster_month=last_day('31-JAN-24') 
--and a.ucid in (select distinct ucid from asit_roster_table where fusionid='105554' ) 
group by last_day(roster_month),a.fusion_id,c.ucid,a.employee_name,c.dept,b."Out Of"

)c on last_day(a.month)=last_day(c.month) and a.fusionid=c.fusion_id
left join(
select 
last_day(a.month) month,a.employee_custom_id,c.dept
--,a.team_leader
,coalesce(round(avg(star_rating),2),0) "Stella Star Rating"
,rank() OVER (PARTITION by last_day(a.month),c.dept  ORDER BY coalesce(round(avg(star_rating),2),0) desc,c.dept ,last_day(a.month) ) "Stella Star Rank"
,b."Out Of"
,case when coalesce(round(avg(star_rating),2),0) >= 4.6 then 4.00
when coalesce(round(avg(star_rating),2),0) >= 4.5 then 3.00 
when coalesce(round(avg(star_rating),2),0) >= 4.4 then 2.00
when coalesce(round(avg(star_rating),2),0) >= 4.3 then 1.00
else 0
end as "Stella Star Score"
from asit_star_rating a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.employee_custom_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
--where  a.month=last_day(a.month)
--and employee_custom_id in ('196400') 
group by last_day(a.month),c.dept,a.employee_custom_id,b."Out Of"
)d on last_day(a.month)=last_day(d.month) and a.fusionid=d.employee_custom_id
left join (
select 
last_day(a.month) month,a.fusion_id,c.dept 
,coalesce(round(adherence_percentage*100,2),0) "Schedule Adherence"
,rank() OVER (PARTITION by last_day(a.month),c.dept ORDER BY coalesce(round(adherence_percentage*100,2),0) desc,c.dept ,last_day(a.month) ) "Adherence Rank"
,b."Out Of"
,case when coalesce(round(adherence_percentage*100,2),0) >=95 then 4.00 
when coalesce(round(adherence_percentage*100,2),0) >=92.5 then 3.00
when coalesce(round(adherence_percentage*100,2),0) >=90 then 2.00 
when coalesce(round(adherence_percentage*100,2),0) >=87.5 then 1.00
else 0
end as
"Adherence Score"
from asit_telephony a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.fusion_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)e on last_day(a.month)=last_day(e.month) and a.fusionid=e.fusion_id
left join (
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
)f on to_char(last_day(a.month),'MON-YY')=f.month and a.fusionid=f.fusionid
left join(
select 
last_day(a.month) month,c.fusionid,a.ucid,c.dept,a.cms_defect_percentage,coalesce(round(a.cms_defect_percentage*100,2),0) "Cms Defect %"
,rank() OVER (PARTITION by a.month ORDER BY coalesce(round(a.cms_defect_percentage*100,2),0) asc,a.month ) "Cms Defect Rank"
,b."Out Of"
,case when coalesce(round(a.cms_defect_percentage*100,2),0) <0.5 then 18.5 
when coalesce(round(a.cms_defect_percentage*100,2),0) <1 then 12.5
when coalesce(round(a.cms_defect_percentage*100,2),0) <=1.5 then 6.25
else 0
end as
"Cms Defect Score"
from asit_cms_defect a
join(
select month,fusionid,ucid,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.ucid=c.ucid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)g on last_day(a.month)=g.month and a.fusionid=g.fusionid
left join(
select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)h on last_day(a.month)=h.monthn and a.dept=h.dept
left join CR_SC_AGNTS_TARGET i on last_day(a.month)=i.month and a.dept=i.dept
where --a.month>=last_day(sysdate)and
 a.dept in ('CCC-R','CCC-R SPANISH','FLEX')
and a.location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and a.designation in ('Agent')
and a.final_status='ACTIVE'
and a.team_leader not in (select name from not_teamleader)
)a)b
--where  "EMPLOYEE ID" in('197233')
group by "EMPLOYEE ID"

) b on a."EMPLOYEE ID"=b."EMPLOYEE ID"
)b
where b.month >= last_day(period)
--where b."EMPLOYEE ID" in('103851')
order by b.month,b."NAME"
--to_date(concat('01-',month)) asc
;
       
 elsif (period is null) then
            OPEN p_result FOR
     
 select 
to_char(b."MONTH",'MON-YY') MONTH,
b."UCID",
b."EMPLOYEE ID",
b."NAME",
b."Team Lead",
b."LOCATION",
b."DEPT",
b."Overall Rank" "Global Rank",
b."Overall Score" "Total Points",
b."Credit Per Hr",
b."Credit Rank",
b."Credits Score",
b."CPH_TARGET",
b."Quality Score",
b."Quality Rank",
b."Quality_Score",
b."QUALITY_TARGET",
b."Stella Star Rating",
b."Stella Star Rank",
b."Stella Star Score",
b."STAR_TARGET",
b."Schedule Adherence",
b."Adherence Rank",
b."Adherence Score",
b."ADHERENCE_TARGET",
b."Inbound AHT",
b."AHT Rank",
b."AHT Score",
b."IB_AHT_TARGET",
b."Cms Defect %",
b."Cms Defect Rank",
b."Cms Defect Score",
b."CMS_DEFECT_TARGET",
b."Out Of",
b."Global Rank" "YTD Global Rank",
b."Global Total Points" "YTD Global Total Points"
from(
select 
a.month  ,a.ucid,a."EMPLOYEE ID",a.name,a."Team Lead",a.location,a.dept
,rank() OVER (PARTITION by a.month,a.dept ORDER BY
(coalesce(a."Credits Score",0)+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+coalesce(a."Adherence Score",0)+coalesce(a."AHT Score",0)
+coalesce(a."Cms Defect Score",0)) desc,a.dept,a.month ) "Overall Rank"
,(coalesce(a."Credits Score",0)+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+coalesce(a."Adherence Score",0)+coalesce(a."AHT Score",0)
+coalesce(a."Cms Defect Score",0)) "Overall Score"
,a."Credit Per Hr",a."Credit Rank",a."Credits Score",a.CPH_TARGET
, a."Quality Score" 
,case when a."Quality Rank" is null then 1 else a."Quality Rank" end as "Quality Rank"
,coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0) as "Quality_Score",a.QUALITY_TARGET
,a."Stella Star Rating" 
,case when a."Stella Star Rank" is null then 1 else a."Stella Star Rank" end as "Stella Star Rank"
,coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0) as "Stella Star Score",a.STAR_TARGET
,a."Schedule Adherence",a."Adherence Rank",a."Adherence Score",a.ADHERENCE_TARGET
,a."Inbound AHT",a."AHT Rank",a."AHT Score",a.IB_AHT_TARGET
,a."Cms Defect %",a."Cms Defect Rank",a."Cms Defect Score",a.CMS_DEFECT_TARGET
,a."Out Of"
,b."Global Rank"
,b."Global Total Points"
from
(
select 
last_day(a.month) month,
a.ucid,
a.fusionid "EMPLOYEE ID",
a.name,
a.team_leader "Team Lead",
a.location,
a.dept
--,rank() OVER (PARTITION by last_day(a.month),a.dept ORDER BY (coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0)) desc,a.dept,last_day(a.month) ) "Global Rank"
--,(coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0))  "Total Points"
,b."Credit Per Hr",b."Credit Rank",b."Credits Score",
--b.CPH_TARGET
i.CPH_TARGET
,c."Quality Score",c."Quality Rank",c."Quality_Score"
,i.QUALITY_TARGET
,d."Stella Star Rating",d."Stella Star Rank",d."Stella Star Score"
,i.STAR_TARGET
,e."Schedule Adherence",e."Adherence Rank",e."Adherence Score"
,i.ADHERENCE_TARGET
,f."Inbound AHT",f."AHT Rank",f."AHT Score"
,i.IB_AHT_TARGET
,g."Cms Defect %",g."Cms Defect Rank",g."Cms Defect Score"
,i.CMS_DEFECT_TARGET
,h."Out Of"
from asit_roster_table a
left join(
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
--,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
,"CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
,e."CPH_TARGET"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
left join(
select month,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95","CPH_TARGET"
from (
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of"
)a )b
where "CPH_TARGET" is not null)e on last_day(a.rpt_month)=last_day(e.month) and c.dept=e.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of",e."CPH_TARGET"
)a
) b on last_day(a.month)=last_day(b.month) and a.fusionid=b.fusionid
left join(
select last_day(roster_month) month,
a.fusion_id,c.ucid,a.employee_name,c.dept
,coalesce(round(avg(score),2),0) "Quality Score"
,rank() OVER (PARTITION by last_day(roster_month),c.dept ORDER BY coalesce(round(avg(score),2),0) desc,c.dept,last_day(roster_month) )  "Quality Rank"
,b."Out Of"
,case 
when coalesce(round(avg(score),2),0) >=97.50  then 3.75 
when coalesce(round(avg(score),2),0) >=95.20  then 2.5
when coalesce(round(avg(score),2),0) >=90  then 1.25 
else 0
end as
"Quality_Score"
from asit_quality a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.roster_month)=c.month and a.fusion_id=c.fusionid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.roster_month)=b.monthn and b.dept=c.dept
--where a.roster_month=last_day('31-JAN-24') 
--and a.ucid in (select distinct ucid from asit_roster_table where fusionid='105554' ) 
group by last_day(roster_month),a.fusion_id,c.ucid,a.employee_name,c.dept,b."Out Of"

)c on last_day(a.month)=last_day(c.month) and a.fusionid=c.fusion_id
left join(
select 
last_day(a.month) month,a.employee_custom_id,c.dept
--,a.team_leader
,coalesce(round(avg(star_rating),2),0) "Stella Star Rating"
,rank() OVER (PARTITION by last_day(a.month),c.dept  ORDER BY coalesce(round(avg(star_rating),2),0) desc,c.dept ,last_day(a.month) ) "Stella Star Rank"
,b."Out Of"
,case when coalesce(round(avg(star_rating),2),0) >= 4.6 then 4.00
when coalesce(round(avg(star_rating),2),0) >= 4.5 then 3.00 
when coalesce(round(avg(star_rating),2),0) >= 4.4 then 2.00
when coalesce(round(avg(star_rating),2),0) >= 4.3 then 1.00
else 0
end as "Stella Star Score"
from asit_star_rating a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.employee_custom_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
--where  a.month=last_day(a.month)
--and employee_custom_id in ('196400') 
group by last_day(a.month),c.dept,a.employee_custom_id,b."Out Of"
)d on last_day(a.month)=last_day(d.month) and a.fusionid=d.employee_custom_id
left join (
select 
last_day(a.month) month,a.fusion_id,c.dept 
,coalesce(round(adherence_percentage*100,2),0) "Schedule Adherence"
,rank() OVER (PARTITION by last_day(a.month),c.dept ORDER BY coalesce(round(adherence_percentage*100,2),0) desc,c.dept ,last_day(a.month) ) "Adherence Rank"
,b."Out Of"
,case when coalesce(round(adherence_percentage*100,2),0) >=95 then 4.00 
when coalesce(round(adherence_percentage*100,2),0) >=92.5 then 3.00
when coalesce(round(adherence_percentage*100,2),0) >=90 then 2.00 
when coalesce(round(adherence_percentage*100,2),0) >=87.5 then 1.00
else 0
end as
"Adherence Score"
from asit_telephony a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.fusion_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)e on last_day(a.month)=last_day(e.month) and a.fusionid=e.fusion_id
left join (
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
)f on to_char(last_day(a.month),'MON-YY')=f.month and a.fusionid=f.fusionid
left join(
select 
last_day(a.month) month,c.fusionid,a.ucid,c.dept,a.cms_defect_percentage,coalesce(round(a.cms_defect_percentage*100,2),0) "Cms Defect %"
,rank() OVER (PARTITION by a.month ORDER BY coalesce(round(a.cms_defect_percentage*100,2),0) asc,a.month ) "Cms Defect Rank"
,b."Out Of"
,case when coalesce(round(a.cms_defect_percentage*100,2),0) <0.5 then 18.5 
when coalesce(round(a.cms_defect_percentage*100,2),0) <1 then 12.5
when coalesce(round(a.cms_defect_percentage*100,2),0) <=1.5 then 6.25
else 0
end as
"Cms Defect Score"
from asit_cms_defect a
join(
select month,fusionid,ucid,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.ucid=c.ucid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)g on last_day(a.month)=g.month and a.fusionid=g.fusionid
left join(
select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)h on last_day(a.month)=h.monthn and a.dept=h.dept
left join CR_SC_AGNTS_TARGET i on last_day(a.month)=i.month and a.dept=i.dept
where --a.month>=last_day(sysdate)and
 a.dept in ('CCC-R','CCC-R SPANISH','FLEX')
and a.location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and a.designation in ('Agent')
and a.final_status='ACTIVE'
and a.team_leader not in (select name from not_teamleader)
)a
left join (
select 
"EMPLOYEE ID"--,name,"Team Lead",location,dept
,rank() OVER (order by sum("Total Points") desc)  "Global Rank"
,sum("Total Points") "Global Total Points"
,avg("Credit Per Hr") "Credit Per Hr",
avg("Quality Score") "Quality Score",avg("Stella Star Rating") "Stella Star Rating",avg("Schedule Adherence") "Schedule Adherence",
avg("Inbound AHT") "Inbound AHT",avg("Cms Defect %") "Cms Defect %"
from
(
select 
to_char(a.month,'MON-YY') month ,a.ucid,a."EMPLOYEE ID",a.name,a."Team Lead",a.location,a.dept
,rank() OVER (PARTITION by a.month,a.dept ORDER BY
(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") desc,a.dept,a.month ) "Global Rank"
,(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") "Total Points"
,coalesce(a."Credit Per Hr",0) "Credit Per Hr" ,a."Credit Rank",a."Credits Score",a.CPH_TARGET
, coalesce (a."Quality Score",0)  "Quality Score"
,case when a."Quality Rank" is null then 1 else a."Quality Rank" end as "Quality Rank"
,coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0) as "Quality_Score",a.QUALITY_TARGET
,coalesce(a."Stella Star Rating",0) "Stella Star Rating"
,case when a."Stella Star Rank" is null then 1 else a."Stella Star Rank" end as "Stella Star Rank"
,coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0) as "Stella Star Score",a.STAR_TARGET
,coalesce(a."Schedule Adherence",0) "Schedule Adherence",a."Adherence Rank",a."Adherence Score",a.ADHERENCE_TARGET
,coalesce(a."Inbound AHT",0) "Inbound AHT",a."AHT Rank",a."AHT Score",a.IB_AHT_TARGET
,coalesce(a."Cms Defect %",0) "Cms Defect %" ,a."Cms Defect Rank",a."Cms Defect Score",a.CMS_DEFECT_TARGET
,a."Out Of"
from
(
select 
last_day(a.month) month,
a.ucid,
a.fusionid "EMPLOYEE ID",
a.name,
a.team_leader "Team Lead",
a.location,
a.dept
--,rank() OVER (PARTITION by last_day(a.month),a.dept ORDER BY (coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0)) desc,a.dept,last_day(a.month) ) "Global Rank"
--,(coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0))  "Total Points"
,b."Credit Per Hr",b."Credit Rank",b."Credits Score",
--b.CPH_TARGET
i.CPH_TARGET
,c."Quality Score",c."Quality Rank",c."Quality_Score"
,i.QUALITY_TARGET
,d."Stella Star Rating",d."Stella Star Rank",d."Stella Star Score"
,i.STAR_TARGET
,e."Schedule Adherence",e."Adherence Rank",e."Adherence Score"
,i.ADHERENCE_TARGET
,f."Inbound AHT",f."AHT Rank",f."AHT Score"
,i.IB_AHT_TARGET
,g."Cms Defect %",g."Cms Defect Rank",g."Cms Defect Score"
,i.CMS_DEFECT_TARGET
,h."Out Of"
from asit_roster_table a
left join(
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
--,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
,"CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
,e."CPH_TARGET"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
left join(
select month,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95","CPH_TARGET"
from (
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of"
)a )b
where "CPH_TARGET" is not null)e on last_day(a.rpt_month)=last_day(e.month) and c.dept=e.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of",e."CPH_TARGET"
)a
) b on last_day(a.month)=last_day(b.month) and a.fusionid=b.fusionid
left join(
select last_day(roster_month) month,
a.fusion_id,c.ucid,a.employee_name,c.dept
,coalesce(round(avg(score),2),0) "Quality Score"
,rank() OVER (PARTITION by last_day(roster_month),c.dept ORDER BY coalesce(round(avg(score),2),0) desc,c.dept,last_day(roster_month) )  "Quality Rank"
,b."Out Of"
,case 
when coalesce(round(avg(score),2),0) >=97.50  then 3.75 
when coalesce(round(avg(score),2),0) >=95.20  then 2.5
when coalesce(round(avg(score),2),0) >=90  then 1.25 
else 0
end as
"Quality_Score"
from asit_quality a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.roster_month)=c.month and a.fusion_id=c.fusionid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.roster_month)=b.monthn and b.dept=c.dept
--where a.roster_month=last_day('31-JAN-24') 
--and a.ucid in (select distinct ucid from asit_roster_table where fusionid='105554' ) 
group by last_day(roster_month),a.fusion_id,c.ucid,a.employee_name,c.dept,b."Out Of"

)c on last_day(a.month)=last_day(c.month) and a.fusionid=c.fusion_id
left join(
select 
last_day(a.month) month,a.employee_custom_id,c.dept
--,a.team_leader
,coalesce(round(avg(star_rating),2),0) "Stella Star Rating"
,rank() OVER (PARTITION by last_day(a.month),c.dept  ORDER BY coalesce(round(avg(star_rating),2),0) desc,c.dept ,last_day(a.month) ) "Stella Star Rank"
,b."Out Of"
,case when coalesce(round(avg(star_rating),2),0) >= 4.6 then 4.00
when coalesce(round(avg(star_rating),2),0) >= 4.5 then 3.00 
when coalesce(round(avg(star_rating),2),0) >= 4.4 then 2.00
when coalesce(round(avg(star_rating),2),0) >= 4.3 then 1.00
else 0
end as "Stella Star Score"
from asit_star_rating a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.employee_custom_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
--where  a.month=last_day(a.month)
--and employee_custom_id in ('196400') 
group by last_day(a.month),c.dept,a.employee_custom_id,b."Out Of"
)d on last_day(a.month)=last_day(d.month) and a.fusionid=d.employee_custom_id
left join (
select 
last_day(a.month) month,a.fusion_id,c.dept 
,coalesce(round(adherence_percentage*100,2),0) "Schedule Adherence"
,rank() OVER (PARTITION by last_day(a.month),c.dept ORDER BY coalesce(round(adherence_percentage*100,2),0) desc,c.dept ,last_day(a.month) ) "Adherence Rank"
,b."Out Of"
,case when coalesce(round(adherence_percentage*100,2),0) >=95 then 4.00 
when coalesce(round(adherence_percentage*100,2),0) >=92.5 then 3.00
when coalesce(round(adherence_percentage*100,2),0) >=90 then 2.00 
when coalesce(round(adherence_percentage*100,2),0) >=87.5 then 1.00
else 0
end as
"Adherence Score"
from asit_telephony a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.fusion_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)e on last_day(a.month)=last_day(e.month) and a.fusionid=e.fusion_id
left join (
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
)f on to_char(last_day(a.month),'MON-YY')=f.month and a.fusionid=f.fusionid
left join(
select 
last_day(a.month) month,c.fusionid,a.ucid,c.dept,a.cms_defect_percentage,coalesce(round(a.cms_defect_percentage*100,2),0) "Cms Defect %"
,rank() OVER (PARTITION by a.month ORDER BY coalesce(round(a.cms_defect_percentage*100,2),0) asc,a.month ) "Cms Defect Rank"
,b."Out Of"
,case when coalesce(round(a.cms_defect_percentage*100,2),0) <0.5 then 18.5 
when coalesce(round(a.cms_defect_percentage*100,2),0) <1 then 12.5
when coalesce(round(a.cms_defect_percentage*100,2),0) <=1.5 then 6.25
else 0
end as
"Cms Defect Score"
from asit_cms_defect a
join(
select month,fusionid,ucid,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.ucid=c.ucid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)g on last_day(a.month)=g.month and a.fusionid=g.fusionid
left join(
select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)h on last_day(a.month)=h.monthn and a.dept=h.dept
left join CR_SC_AGNTS_TARGET i on last_day(a.month)=i.month and a.dept=i.dept
where --a.month>=last_day(sysdate)and
 a.dept in ('CCC-R','CCC-R SPANISH','FLEX')
and a.location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and a.designation in ('Agent')
and a.final_status='ACTIVE'
and a.team_leader not in (select name from not_teamleader)
)a)b
--where  "EMPLOYEE ID" in('197233')
group by "EMPLOYEE ID"

) b on a."EMPLOYEE ID"=b."EMPLOYEE ID"
)b
--where b.month >= last_day('21-Feb-24')
where b."EMPLOYEE ID" in(vfusionid)
order by b.month,b."NAME"
--to_date(concat('01-',month)) asc
;
     
            
            else
            OPEN p_result FOR  
select 
to_char(b."MONTH",'MON-YY') MONTH,
b."UCID",
b."EMPLOYEE ID",
b."NAME",
b."Team Lead",
b."LOCATION",
b."DEPT",
b."Overall Rank" "Global Rank",
b."Overall Score" "Total Points",
b."Credit Per Hr",
b."Credit Rank",
b."Credits Score",
b."CPH_TARGET",
b."Quality Score",
b."Quality Rank",
b."Quality_Score",
b."QUALITY_TARGET",
b."Stella Star Rating",
b."Stella Star Rank",
b."Stella Star Score",
b."STAR_TARGET",
b."Schedule Adherence",
b."Adherence Rank",
b."Adherence Score",
b."ADHERENCE_TARGET",
b."Inbound AHT",
b."AHT Rank",
b."AHT Score",
b."IB_AHT_TARGET",
b."Cms Defect %",
b."Cms Defect Rank",
b."Cms Defect Score",
b."CMS_DEFECT_TARGET",
b."Out Of",
b."Global Rank" "YTD Global Rank",
b."Global Total Points" "YTD Global Total Points"
from(
select 
a.month  ,a.ucid,a."EMPLOYEE ID",a.name,a."Team Lead",a.location,a.dept
,rank() OVER (PARTITION by a.month,a.dept ORDER BY
(coalesce(a."Credits Score",0)+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+coalesce(a."Adherence Score",0)+coalesce(a."AHT Score",0)
+coalesce(a."Cms Defect Score",0)) desc,a.dept,a.month ) "Overall Rank"
,(coalesce(a."Credits Score",0)+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+coalesce(a."Adherence Score",0)+coalesce(a."AHT Score",0)
+coalesce(a."Cms Defect Score",0)) "Overall Score"
,a."Credit Per Hr",a."Credit Rank",a."Credits Score",a.CPH_TARGET
, a."Quality Score" 
,case when a."Quality Rank" is null then 1 else a."Quality Rank" end as "Quality Rank"
,coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0) as "Quality_Score",a.QUALITY_TARGET
,a."Stella Star Rating" 
,case when a."Stella Star Rank" is null then 1 else a."Stella Star Rank" end as "Stella Star Rank"
,coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0) as "Stella Star Score",a.STAR_TARGET
,a."Schedule Adherence",a."Adherence Rank",a."Adherence Score",a.ADHERENCE_TARGET
,a."Inbound AHT",a."AHT Rank",a."AHT Score",a.IB_AHT_TARGET
,a."Cms Defect %",a."Cms Defect Rank",a."Cms Defect Score",a.CMS_DEFECT_TARGET
,a."Out Of"
,b."Global Rank"
,b."Global Total Points"
from
(
select 
last_day(a.month) month,
a.ucid,
a.fusionid "EMPLOYEE ID",
a.name,
a.team_leader "Team Lead",
a.location,
a.dept
--,rank() OVER (PARTITION by last_day(a.month),a.dept ORDER BY (coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0)) desc,a.dept,last_day(a.month) ) "Global Rank"
--,(coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0))  "Total Points"
,b."Credit Per Hr",b."Credit Rank",b."Credits Score",
--b.CPH_TARGET
i.CPH_TARGET
,c."Quality Score",c."Quality Rank",c."Quality_Score"
,i.QUALITY_TARGET
,d."Stella Star Rating",d."Stella Star Rank",d."Stella Star Score"
,i.STAR_TARGET
,e."Schedule Adherence",e."Adherence Rank",e."Adherence Score"
,i.ADHERENCE_TARGET
,f."Inbound AHT",f."AHT Rank",f."AHT Score"
,i.IB_AHT_TARGET
,g."Cms Defect %",g."Cms Defect Rank",g."Cms Defect Score"
,i.CMS_DEFECT_TARGET
,h."Out Of"
from asit_roster_table a
left join(
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
--,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
,"CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
,e."CPH_TARGET"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
left join(
select month,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95","CPH_TARGET"
from (
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of"
)a )b
where "CPH_TARGET" is not null)e on last_day(a.rpt_month)=last_day(e.month) and c.dept=e.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of",e."CPH_TARGET"
)a
) b on last_day(a.month)=last_day(b.month) and a.fusionid=b.fusionid
left join(
select last_day(roster_month) month,
a.fusion_id,c.ucid,a.employee_name,c.dept
,coalesce(round(avg(score),2),0) "Quality Score"
,rank() OVER (PARTITION by last_day(roster_month),c.dept ORDER BY coalesce(round(avg(score),2),0) desc,c.dept,last_day(roster_month) )  "Quality Rank"
,b."Out Of"
,case 
when coalesce(round(avg(score),2),0) >=97.50  then 3.75 
when coalesce(round(avg(score),2),0) >=95.20  then 2.5
when coalesce(round(avg(score),2),0) >=90  then 1.25 
else 0
end as
"Quality_Score"
from asit_quality a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.roster_month)=c.month and a.fusion_id=c.fusionid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.roster_month)=b.monthn and b.dept=c.dept
--where a.roster_month=last_day('31-JAN-24') 
--and a.ucid in (select distinct ucid from asit_roster_table where fusionid='105554' ) 
group by last_day(roster_month),a.fusion_id,c.ucid,a.employee_name,c.dept,b."Out Of"

)c on last_day(a.month)=last_day(c.month) and a.fusionid=c.fusion_id
left join(
select 
last_day(a.month) month,a.employee_custom_id,c.dept
--,a.team_leader
,coalesce(round(avg(star_rating),2),0) "Stella Star Rating"
,rank() OVER (PARTITION by last_day(a.month),c.dept  ORDER BY coalesce(round(avg(star_rating),2),0) desc,c.dept ,last_day(a.month) ) "Stella Star Rank"
,b."Out Of"
,case when coalesce(round(avg(star_rating),2),0) >= 4.6 then 4.00
when coalesce(round(avg(star_rating),2),0) >= 4.5 then 3.00 
when coalesce(round(avg(star_rating),2),0) >= 4.4 then 2.00
when coalesce(round(avg(star_rating),2),0) >= 4.3 then 1.00
else 0
end as "Stella Star Score"
from asit_star_rating a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.employee_custom_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
--where  a.month=last_day(a.month)
--and employee_custom_id in ('196400') 
group by last_day(a.month),c.dept,a.employee_custom_id,b."Out Of"
)d on last_day(a.month)=last_day(d.month) and a.fusionid=d.employee_custom_id
left join (
select 
last_day(a.month) month,a.fusion_id,c.dept 
,coalesce(round(adherence_percentage*100,2),0) "Schedule Adherence"
,rank() OVER (PARTITION by last_day(a.month),c.dept ORDER BY coalesce(round(adherence_percentage*100,2),0) desc,c.dept ,last_day(a.month) ) "Adherence Rank"
,b."Out Of"
,case when coalesce(round(adherence_percentage*100,2),0) >=95 then 4.00 
when coalesce(round(adherence_percentage*100,2),0) >=92.5 then 3.00
when coalesce(round(adherence_percentage*100,2),0) >=90 then 2.00 
when coalesce(round(adherence_percentage*100,2),0) >=87.5 then 1.00
else 0
end as
"Adherence Score"
from asit_telephony a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.fusion_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)e on last_day(a.month)=last_day(e.month) and a.fusionid=e.fusion_id
left join (
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
)f on to_char(last_day(a.month),'MON-YY')=f.month and a.fusionid=f.fusionid
left join(
select 
last_day(a.month) month,c.fusionid,a.ucid,c.dept,a.cms_defect_percentage,coalesce(round(a.cms_defect_percentage*100,2),0) "Cms Defect %"
,rank() OVER (PARTITION by a.month ORDER BY coalesce(round(a.cms_defect_percentage*100,2),0) asc,a.month ) "Cms Defect Rank"
,b."Out Of"
,case when coalesce(round(a.cms_defect_percentage*100,2),0) <0.5 then 18.5 
when coalesce(round(a.cms_defect_percentage*100,2),0) <1 then 12.5
when coalesce(round(a.cms_defect_percentage*100,2),0) <=1.5 then 6.25
else 0
end as
"Cms Defect Score"
from asit_cms_defect a
join(
select month,fusionid,ucid,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.ucid=c.ucid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)g on last_day(a.month)=g.month and a.fusionid=g.fusionid
left join(
select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)h on last_day(a.month)=h.monthn and a.dept=h.dept
left join CR_SC_AGNTS_TARGET i on last_day(a.month)=i.month and a.dept=i.dept
where --a.month>=last_day(sysdate)and
 a.dept in ('CCC-R','CCC-R SPANISH','FLEX')
and a.location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and a.designation in ('Agent')
and a.final_status='ACTIVE'
and a.team_leader not in (select name from not_teamleader)
)a
left join (
select 
"EMPLOYEE ID"--,name,"Team Lead",location,dept
,rank() OVER (order by sum("Total Points") desc)  "Global Rank"
,sum("Total Points") "Global Total Points"
,avg("Credit Per Hr") "Credit Per Hr",
avg("Quality Score") "Quality Score",avg("Stella Star Rating") "Stella Star Rating",avg("Schedule Adherence") "Schedule Adherence",
avg("Inbound AHT") "Inbound AHT",avg("Cms Defect %") "Cms Defect %"
from
(
select 
to_char(a.month,'MON-YY') month ,a.ucid,a."EMPLOYEE ID",a.name,a."Team Lead",a.location,a.dept
,rank() OVER (PARTITION by a.month,a.dept ORDER BY
(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") desc,a.dept,a.month ) "Global Rank"
,(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") "Total Points"
,coalesce(a."Credit Per Hr",0) "Credit Per Hr" ,a."Credit Rank",a."Credits Score",a.CPH_TARGET
, coalesce (a."Quality Score",0)  "Quality Score"
,case when a."Quality Rank" is null then 1 else a."Quality Rank" end as "Quality Rank"
,coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0) as "Quality_Score",a.QUALITY_TARGET
,coalesce(a."Stella Star Rating",0) "Stella Star Rating"
,case when a."Stella Star Rank" is null then 1 else a."Stella Star Rank" end as "Stella Star Rank"
,coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0) as "Stella Star Score",a.STAR_TARGET
,coalesce(a."Schedule Adherence",0) "Schedule Adherence",a."Adherence Rank",a."Adherence Score",a.ADHERENCE_TARGET
,coalesce(a."Inbound AHT",0) "Inbound AHT",a."AHT Rank",a."AHT Score",a.IB_AHT_TARGET
,coalesce(a."Cms Defect %",0) "Cms Defect %" ,a."Cms Defect Rank",a."Cms Defect Score",a.CMS_DEFECT_TARGET
,a."Out Of"
from
(
select 
last_day(a.month) month,
a.ucid,
a.fusionid "EMPLOYEE ID",
a.name,
a.team_leader "Team Lead",
a.location,
a.dept
--,rank() OVER (PARTITION by last_day(a.month),a.dept ORDER BY (coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0)) desc,a.dept,last_day(a.month) ) "Global Rank"
--,(coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0))  "Total Points"
,b."Credit Per Hr",b."Credit Rank",b."Credits Score",
--b.CPH_TARGET
i.CPH_TARGET
,c."Quality Score",c."Quality Rank",c."Quality_Score"
,i.QUALITY_TARGET
,d."Stella Star Rating",d."Stella Star Rank",d."Stella Star Score"
,i.STAR_TARGET
,e."Schedule Adherence",e."Adherence Rank",e."Adherence Score"
,i.ADHERENCE_TARGET
,f."Inbound AHT",f."AHT Rank",f."AHT Score"
,i.IB_AHT_TARGET
,g."Cms Defect %",g."Cms Defect Rank",g."Cms Defect Score"
,i.CMS_DEFECT_TARGET
,h."Out Of"
from asit_roster_table a
left join(
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
--,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
,"CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
,e."CPH_TARGET"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
left join(
select month,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95","CPH_TARGET"
from (
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of"
)a )b
where "CPH_TARGET" is not null)e on last_day(a.rpt_month)=last_day(e.month) and c.dept=e.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of",e."CPH_TARGET"
)a
) b on last_day(a.month)=last_day(b.month) and a.fusionid=b.fusionid
left join(
select last_day(roster_month) month,
a.fusion_id,c.ucid,a.employee_name,c.dept
,coalesce(round(avg(score),2),0) "Quality Score"
,rank() OVER (PARTITION by last_day(roster_month),c.dept ORDER BY coalesce(round(avg(score),2),0) desc,c.dept,last_day(roster_month) )  "Quality Rank"
,b."Out Of"
,case 
when coalesce(round(avg(score),2),0) >=97.50  then 3.75 
when coalesce(round(avg(score),2),0) >=95.20  then 2.5
when coalesce(round(avg(score),2),0) >=90  then 1.25 
else 0
end as
"Quality_Score"
from asit_quality a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.roster_month)=c.month and a.fusion_id=c.fusionid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.roster_month)=b.monthn and b.dept=c.dept
--where a.roster_month=last_day('31-JAN-24') 
--and a.ucid in (select distinct ucid from asit_roster_table where fusionid='105554' ) 
group by last_day(roster_month),a.fusion_id,c.ucid,a.employee_name,c.dept,b."Out Of"

)c on last_day(a.month)=last_day(c.month) and a.fusionid=c.fusion_id
left join(
select 
last_day(a.month) month,a.employee_custom_id,c.dept
--,a.team_leader
,coalesce(round(avg(star_rating),2),0) "Stella Star Rating"
,rank() OVER (PARTITION by last_day(a.month),c.dept  ORDER BY coalesce(round(avg(star_rating),2),0) desc,c.dept ,last_day(a.month) ) "Stella Star Rank"
,b."Out Of"
,case when coalesce(round(avg(star_rating),2),0) >= 4.6 then 4.00
when coalesce(round(avg(star_rating),2),0) >= 4.5 then 3.00 
when coalesce(round(avg(star_rating),2),0) >= 4.4 then 2.00
when coalesce(round(avg(star_rating),2),0) >= 4.3 then 1.00
else 0
end as "Stella Star Score"
from asit_star_rating a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.employee_custom_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
--where  a.month=last_day(a.month)
--and employee_custom_id in ('196400') 
group by last_day(a.month),c.dept,a.employee_custom_id,b."Out Of"
)d on last_day(a.month)=last_day(d.month) and a.fusionid=d.employee_custom_id
left join (
select 
last_day(a.month) month,a.fusion_id,c.dept 
,coalesce(round(adherence_percentage*100,2),0) "Schedule Adherence"
,rank() OVER (PARTITION by last_day(a.month),c.dept ORDER BY coalesce(round(adherence_percentage*100,2),0) desc,c.dept ,last_day(a.month) ) "Adherence Rank"
,b."Out Of"
,case when coalesce(round(adherence_percentage*100,2),0) >=95 then 4.00 
when coalesce(round(adherence_percentage*100,2),0) >=92.5 then 3.00
when coalesce(round(adherence_percentage*100,2),0) >=90 then 2.00 
when coalesce(round(adherence_percentage*100,2),0) >=87.5 then 1.00
else 0
end as
"Adherence Score"
from asit_telephony a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.fusion_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)e on last_day(a.month)=last_day(e.month) and a.fusionid=e.fusion_id
left join (
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
)f on to_char(last_day(a.month),'MON-YY')=f.month and a.fusionid=f.fusionid
left join(
select 
last_day(a.month) month,c.fusionid,a.ucid,c.dept,a.cms_defect_percentage,coalesce(round(a.cms_defect_percentage*100,2),0) "Cms Defect %"
,rank() OVER (PARTITION by a.month ORDER BY coalesce(round(a.cms_defect_percentage*100,2),0) asc,a.month ) "Cms Defect Rank"
,b."Out Of"
,case when coalesce(round(a.cms_defect_percentage*100,2),0) <0.5 then 18.5 
when coalesce(round(a.cms_defect_percentage*100,2),0) <1 then 12.5
when coalesce(round(a.cms_defect_percentage*100,2),0) <=1.5 then 6.25
else 0
end as
"Cms Defect Score"
from asit_cms_defect a
join(
select month,fusionid,ucid,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.ucid=c.ucid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)g on last_day(a.month)=g.month and a.fusionid=g.fusionid
left join(
select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)h on last_day(a.month)=h.monthn and a.dept=h.dept
left join CR_SC_AGNTS_TARGET i on last_day(a.month)=i.month and a.dept=i.dept
where --a.month>=last_day(sysdate)and
 a.dept in ('CCC-R','CCC-R SPANISH','FLEX')
and a.location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and a.designation in ('Agent')
and a.final_status='ACTIVE'
and a.team_leader not in (select name from not_teamleader)
)a)b
--where  "EMPLOYEE ID" in('197233')
group by "EMPLOYEE ID"

) b on a."EMPLOYEE ID"=b."EMPLOYEE ID"
)b
where b.month >= last_day(period)
and b."EMPLOYEE ID" in(vfusionid)
order by b.month,b."NAME"
--to_date(concat('01-',month)) asc
;
    
    end if;
  END CR_SC_MTD_AGNTS;
 
PROCEDURE CR_SC_YTD_AGNTS (
    vfusionid2 in VARCHAR2, p_result OUT SYS_REFCURSOR) is 
  BEGIN
      if(vfusionid2 is null) then       
            OPEN p_result FOR  
select 
a."EMPLOYEE ID",
a."EMPLOYEE_NAME",
a."DEPT",
a."Global Rank",
a."Total Points",
a."Credit Per Hr",
a."Quality Score",
a."Stella Star Rating",
a."Schedule Adherence",
a."Inbound AHT",
a."Cms Defect %",
 case when a."Global Rank" <= round(b."Out_of"*0.10,0) then 1 
 when a."Global Rank" <= (round(b."Out_of"*0.20,0)+round(b."Out_of"*0.10,0)) then 2 
  when a."Global Rank" <= (round(b."Out_of"*0.40,0)+round(b."Out_of"*0.20,0)+round(b."Out_of"*0.10,0)) then 3 
  when a."Global Rank" <= (round(b."Out_of"*0.20,0)+round(b."Out_of"*0.40,0)+round(b."Out_of"*0.20,0)+round(b."Out_of"*0.10,0)) then 4 
  else 5
 end TIER,
b."Out_of"
from (
select 
"EMPLOYEE ID"
,upper(name) "EMPLOYEE_NAME"--,"Team Lead",location
,dept
,rank() OVER (partition by dept order by sum("Total Points") desc,dept)  "Global Rank"
,round(sum("Total Points"),3) "Total Points"
,round(avg("Credit Per Hr"),3) "Credit Per Hr",
round(avg("Quality Score"),3) "Quality Score",
round(avg("Stella Star Rating"),3) "Stella Star Rating",
round(avg("Schedule Adherence"),3) "Schedule Adherence",
round(avg("Inbound AHT"),3) "Inbound AHT",round(avg("Cms Defect %"),3) "Cms Defect %"
from
(
select 
to_char(a.month,'MON-YY') month ,a.ucid,a."EMPLOYEE ID",a.name,a."Team Lead",a.location,a.dept
,rank() OVER (PARTITION by a.month,a.dept ORDER BY
(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") desc,a.dept,a.month ) "Global Rank"
,(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") "Total Points"
,coalesce(a."Credit Per Hr",0) "Credit Per Hr" ,a."Credit Rank",a."Credits Score",a.CPH_TARGET
, coalesce (a."Quality Score",0)  "Quality Score"
,case when a."Quality Rank" is null then 1 else a."Quality Rank" end as "Quality Rank"
,coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0) as "Quality_Score",a.QUALITY_TARGET
,coalesce(a."Stella Star Rating",0) "Stella Star Rating"
,case when a."Stella Star Rank" is null then 1 else a."Stella Star Rank" end as "Stella Star Rank"
,coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0) as "Stella Star Score",a.STAR_TARGET
,coalesce(a."Schedule Adherence",0) "Schedule Adherence",a."Adherence Rank",a."Adherence Score",a.ADHERENCE_TARGET
,coalesce(a."Inbound AHT",0) "Inbound AHT",a."AHT Rank",a."AHT Score",a.IB_AHT_TARGET
,coalesce(a."Cms Defect %",0) "Cms Defect %" ,a."Cms Defect Rank",a."Cms Defect Score",a.CMS_DEFECT_TARGET
,a."Out Of"
from
(
select 
last_day(a.month) month,
a.ucid,
a.fusionid "EMPLOYEE ID",
a.name,
a.team_leader "Team Lead",
a.location,
a.dept
--,rank() OVER (PARTITION by last_day(a.month),a.dept ORDER BY (coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0)) desc,a.dept,last_day(a.month) ) "Global Rank"
--,(coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0))  "Total Points"
,b."Credit Per Hr",b."Credit Rank",b."Credits Score",
--b.CPH_TARGET
i.CPH_TARGET
,c."Quality Score",c."Quality Rank",c."Quality_Score"
,i.QUALITY_TARGET
,d."Stella Star Rating",d."Stella Star Rank",d."Stella Star Score"
,i.STAR_TARGET
,e."Schedule Adherence",e."Adherence Rank",e."Adherence Score"
,i.ADHERENCE_TARGET
,f."Inbound AHT",f."AHT Rank",f."AHT Score"
,i.IB_AHT_TARGET
,g."Cms Defect %",g."Cms Defect Rank",g."Cms Defect Score"
,i.CMS_DEFECT_TARGET
,h."Out Of"
from asit_roster_table a
left join(
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
--,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
,"CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
,e."CPH_TARGET"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
left join(
select month,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95","CPH_TARGET"
from (
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of"
)a )b
where "CPH_TARGET" is not null)e on last_day(a.rpt_month)=last_day(e.month) and c.dept=e.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of",e."CPH_TARGET"
)a
) b on last_day(a.month)=last_day(b.month) and a.fusionid=b.fusionid
left join(
select last_day(roster_month) month,
a.fusion_id,c.ucid,a.employee_name,c.dept
,coalesce(round(avg(score),2),0) "Quality Score"
,rank() OVER (PARTITION by last_day(roster_month),c.dept ORDER BY coalesce(round(avg(score),2),0) desc,c.dept,last_day(roster_month) )  "Quality Rank"
,b."Out Of"
,case 
when coalesce(round(avg(score),2),0) >=97.50  then 3.75 
when coalesce(round(avg(score),2),0) >=95.20  then 2.5
when coalesce(round(avg(score),2),0) >=90  then 1.25 
else 0
end as
"Quality_Score"
from asit_quality a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.roster_month)=c.month and a.fusion_id=c.fusionid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.roster_month)=b.monthn and b.dept=c.dept
--where a.roster_month=last_day('31-JAN-24') 
--and a.ucid in (select distinct ucid from asit_roster_table where fusionid='105554' ) 
group by last_day(roster_month),a.fusion_id,c.ucid,a.employee_name,c.dept,b."Out Of"

)c on last_day(a.month)=last_day(c.month) and a.fusionid=c.fusion_id
left join(
select 
last_day(a.month) month,a.employee_custom_id,c.dept
--,a.team_leader
,coalesce(round(avg(star_rating),2),0) "Stella Star Rating"
,rank() OVER (PARTITION by last_day(a.month),c.dept  ORDER BY coalesce(round(avg(star_rating),2),0) desc,c.dept ,last_day(a.month) ) "Stella Star Rank"
,b."Out Of"
,case when coalesce(round(avg(star_rating),2),0) >= 4.6 then 4.00
when coalesce(round(avg(star_rating),2),0) >= 4.5 then 3.00 
when coalesce(round(avg(star_rating),2),0) >= 4.4 then 2.00
when coalesce(round(avg(star_rating),2),0) >= 4.3 then 1.00
else 0
end as "Stella Star Score"
from asit_star_rating a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.employee_custom_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
--where  a.month=last_day(a.month)
--and employee_custom_id in ('196400') 
group by last_day(a.month),c.dept,a.employee_custom_id,b."Out Of"
)d on last_day(a.month)=last_day(d.month) and a.fusionid=d.employee_custom_id
left join (
select 
last_day(a.month) month,a.fusion_id,c.dept 
,coalesce(round(adherence_percentage*100,2),0) "Schedule Adherence"
,rank() OVER (PARTITION by last_day(a.month),c.dept ORDER BY coalesce(round(adherence_percentage*100,2),0) desc,c.dept ,last_day(a.month) ) "Adherence Rank"
,b."Out Of"
,case when coalesce(round(adherence_percentage*100,2),0) >=95 then 4.00 
when coalesce(round(adherence_percentage*100,2),0) >=92.5 then 3.00
when coalesce(round(adherence_percentage*100,2),0) >=90 then 2.00 
when coalesce(round(adherence_percentage*100,2),0) >=87.5 then 1.00
else 0
end as
"Adherence Score"
from asit_telephony a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.fusion_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)e on last_day(a.month)=last_day(e.month) and a.fusionid=e.fusion_id
left join (
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
)f on to_char(last_day(a.month),'MON-YY')=f.month and a.fusionid=f.fusionid
left join(
select 
last_day(a.month) month,c.fusionid,a.ucid,c.dept,a.cms_defect_percentage,coalesce(round(a.cms_defect_percentage*100,2),0) "Cms Defect %"
,rank() OVER (PARTITION by a.month ORDER BY coalesce(round(a.cms_defect_percentage*100,2),0) asc,a.month ) "Cms Defect Rank"
,b."Out Of"
,case when coalesce(round(a.cms_defect_percentage*100,2),0) <0.5 then 18.5 
when coalesce(round(a.cms_defect_percentage*100,2),0) <1 then 12.5
when coalesce(round(a.cms_defect_percentage*100,2),0) <=1.5 then 6.25
else 0
end as
"Cms Defect Score"
from asit_cms_defect a
join(
select month,fusionid,ucid,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.ucid=c.ucid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)g on last_day(a.month)=g.month and a.fusionid=g.fusionid
left join(
select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)h on last_day(a.month)=h.monthn and a.dept=h.dept
left join CR_SC_AGNTS_TARGET i on last_day(a.month)=i.month and a.dept=i.dept
where --a.month>=last_day(sysdate)and
 a.dept in ('CCC-R','CCC-R SPANISH','FLEX')
and a.location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and a.designation in ('Agent')
and a.final_status='ACTIVE'
and a.team_leader not in (select name from not_teamleader)
)a)b
--where  "EMPLOYEE ID" in('197233')
group by "EMPLOYEE ID",name,dept
)a
left join
(
select 
a."DEPT",
count(a."Global Rank") "Out_of"
from (
select 
"EMPLOYEE ID"
,upper(name) "EMPLOYEE_NAME"--,"Team Lead",location
,dept
,rank() OVER (order by sum("Total Points") desc)  "Global Rank"
,round(sum("Total Points"),3) "Total Points"
,round(avg("Credit Per Hr"),3) "Credit Per Hr",
round(avg("Quality Score"),3) "Quality Score",
round(avg("Stella Star Rating"),3) "Stella Star Rating",
round(avg("Schedule Adherence"),3) "Schedule Adherence",
round(avg("Inbound AHT"),3) "Inbound AHT",round(avg("Cms Defect %"),3) "Cms Defect %"
from
(
select 
to_char(a.month,'MON-YY') month ,a.ucid,a."EMPLOYEE ID",a.name,a."Team Lead",a.location,a.dept
,rank() OVER (PARTITION by a.month,a.dept ORDER BY
(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") desc,a.dept,a.month ) "Global Rank"
,(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") "Total Points"
,coalesce(a."Credit Per Hr",0) "Credit Per Hr" ,a."Credit Rank",a."Credits Score",a.CPH_TARGET
, coalesce (a."Quality Score",0)  "Quality Score"
,case when a."Quality Rank" is null then 1 else a."Quality Rank" end as "Quality Rank"
,coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0) as "Quality_Score",a.QUALITY_TARGET
,coalesce(a."Stella Star Rating",0) "Stella Star Rating"
,case when a."Stella Star Rank" is null then 1 else a."Stella Star Rank" end as "Stella Star Rank"
,coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0) as "Stella Star Score",a.STAR_TARGET
,coalesce(a."Schedule Adherence",0) "Schedule Adherence",a."Adherence Rank",a."Adherence Score",a.ADHERENCE_TARGET
,coalesce(a."Inbound AHT",0) "Inbound AHT",a."AHT Rank",a."AHT Score",a.IB_AHT_TARGET
,coalesce(a."Cms Defect %",0) "Cms Defect %" ,a."Cms Defect Rank",a."Cms Defect Score",a.CMS_DEFECT_TARGET
,a."Out Of"
from
(
select 
last_day(a.month) month,
a.ucid,
a.fusionid "EMPLOYEE ID",
a.name,
a.team_leader "Team Lead",
a.location,
a.dept
--,rank() OVER (PARTITION by last_day(a.month),a.dept ORDER BY (coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0)) desc,a.dept,last_day(a.month) ) "Global Rank"
--,(coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0))  "Total Points"
,b."Credit Per Hr",b."Credit Rank",b."Credits Score",
--b.CPH_TARGET
i.CPH_TARGET
,c."Quality Score",c."Quality Rank",c."Quality_Score"
,i.QUALITY_TARGET
,d."Stella Star Rating",d."Stella Star Rank",d."Stella Star Score"
,i.STAR_TARGET
,e."Schedule Adherence",e."Adherence Rank",e."Adherence Score"
,i.ADHERENCE_TARGET
,f."Inbound AHT",f."AHT Rank",f."AHT Score"
,i.IB_AHT_TARGET
,g."Cms Defect %",g."Cms Defect Rank",g."Cms Defect Score"
,i.CMS_DEFECT_TARGET
,h."Out Of"
from asit_roster_table a
left join(
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
--,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
,"CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
,e."CPH_TARGET"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
left join(
select month,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95","CPH_TARGET"
from (
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of"
)a )b
where "CPH_TARGET" is not null)e on last_day(a.rpt_month)=last_day(e.month) and c.dept=e.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of",e."CPH_TARGET"
)a
) b on last_day(a.month)=last_day(b.month) and a.fusionid=b.fusionid
left join(
select last_day(roster_month) month,
a.fusion_id,c.ucid,a.employee_name,c.dept
,coalesce(round(avg(score),2),0) "Quality Score"
,rank() OVER (PARTITION by last_day(roster_month),c.dept ORDER BY coalesce(round(avg(score),2),0) desc,c.dept,last_day(roster_month) )  "Quality Rank"
,b."Out Of"
,case 
when coalesce(round(avg(score),2),0) >=97.50  then 3.75 
when coalesce(round(avg(score),2),0) >=95.20  then 2.5
when coalesce(round(avg(score),2),0) >=90  then 1.25 
else 0
end as
"Quality_Score"
from asit_quality a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.roster_month)=c.month and a.fusion_id=c.fusionid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.roster_month)=b.monthn and b.dept=c.dept
--where a.roster_month=last_day('31-JAN-24') 
--and a.ucid in (select distinct ucid from asit_roster_table where fusionid='105554' ) 
group by last_day(roster_month),a.fusion_id,c.ucid,a.employee_name,c.dept,b."Out Of"

)c on last_day(a.month)=last_day(c.month) and a.fusionid=c.fusion_id
left join(
select 
last_day(a.month) month,a.employee_custom_id,c.dept
--,a.team_leader
,coalesce(round(avg(star_rating),2),0) "Stella Star Rating"
,rank() OVER (PARTITION by last_day(a.month),c.dept  ORDER BY coalesce(round(avg(star_rating),2),0) desc,c.dept ,last_day(a.month) ) "Stella Star Rank"
,b."Out Of"
,case when coalesce(round(avg(star_rating),2),0) >= 4.6 then 4.00
when coalesce(round(avg(star_rating),2),0) >= 4.5 then 3.00 
when coalesce(round(avg(star_rating),2),0) >= 4.4 then 2.00
when coalesce(round(avg(star_rating),2),0) >= 4.3 then 1.00
else 0
end as "Stella Star Score"
from asit_star_rating a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.employee_custom_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
--where  a.month=last_day(a.month)
--and employee_custom_id in ('196400') 
group by last_day(a.month),c.dept,a.employee_custom_id,b."Out Of"
)d on last_day(a.month)=last_day(d.month) and a.fusionid=d.employee_custom_id
left join (
select 
last_day(a.month) month,a.fusion_id,c.dept 
,coalesce(round(adherence_percentage*100,2),0) "Schedule Adherence"
,rank() OVER (PARTITION by last_day(a.month),c.dept ORDER BY coalesce(round(adherence_percentage*100,2),0) desc,c.dept ,last_day(a.month) ) "Adherence Rank"
,b."Out Of"
,case when coalesce(round(adherence_percentage*100,2),0) >=95 then 4.00 
when coalesce(round(adherence_percentage*100,2),0) >=92.5 then 3.00
when coalesce(round(adherence_percentage*100,2),0) >=90 then 2.00 
when coalesce(round(adherence_percentage*100,2),0) >=87.5 then 1.00
else 0
end as
"Adherence Score"
from asit_telephony a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.fusion_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)e on last_day(a.month)=last_day(e.month) and a.fusionid=e.fusion_id
left join (
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
)f on to_char(last_day(a.month),'MON-YY')=f.month and a.fusionid=f.fusionid
left join(
select 
last_day(a.month) month,c.fusionid,a.ucid,c.dept,a.cms_defect_percentage,coalesce(round(a.cms_defect_percentage*100,2),0) "Cms Defect %"
,rank() OVER (PARTITION by a.month ORDER BY coalesce(round(a.cms_defect_percentage*100,2),0) asc,a.month ) "Cms Defect Rank"
,b."Out Of"
,case when coalesce(round(a.cms_defect_percentage*100,2),0) <0.5 then 18.5 
when coalesce(round(a.cms_defect_percentage*100,2),0) <1 then 12.5
when coalesce(round(a.cms_defect_percentage*100,2),0) <=1.5 then 6.25
else 0
end as
"Cms Defect Score"
from asit_cms_defect a
join(
select month,fusionid,ucid,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.ucid=c.ucid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)g on last_day(a.month)=g.month and a.fusionid=g.fusionid
left join(
select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)h on last_day(a.month)=h.monthn and a.dept=h.dept
left join CR_SC_AGNTS_TARGET i on last_day(a.month)=i.month and a.dept=i.dept
where --a.month>=last_day(sysdate)and
 a.dept in ('CCC-R','CCC-R SPANISH','FLEX')
and a.location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and a.designation in ('Agent')
and a.final_status='ACTIVE'
and a.team_leader not in (select name from not_teamleader)
)a)b
--where  "EMPLOYEE ID" in('197233')
group by "EMPLOYEE ID",name,dept
)a
group by a.dept
)b on a.dept=b.dept
--where a."EMPLOYEE ID" in (vfusionid2)
--('197043')
order by a."Global Rank"
;

else 
 open p_result for
select 
a."EMPLOYEE ID",
a."EMPLOYEE_NAME",
a."DEPT",
a."Global Rank",
a."Total Points",
a."Credit Per Hr",
a."Quality Score",
a."Stella Star Rating",
a."Schedule Adherence",
a."Inbound AHT",
a."Cms Defect %",
 case when a."Global Rank" <= round(b."Out_of"*0.10,0) then 1 
 when a."Global Rank" <= (round(b."Out_of"*0.20,0)+round(b."Out_of"*0.10,0)) then 2 
  when a."Global Rank" <= (round(b."Out_of"*0.40,0)+round(b."Out_of"*0.20,0)+round(b."Out_of"*0.10,0)) then 3 
  when a."Global Rank" <= (round(b."Out_of"*0.20,0)+round(b."Out_of"*0.40,0)+round(b."Out_of"*0.20,0)+round(b."Out_of"*0.10,0)) then 4 
  else 5
 end TIER,
b."Out_of"
from (
select 
"EMPLOYEE ID"
,upper(name) "EMPLOYEE_NAME"--,"Team Lead",location
,dept
,rank() OVER (partition by dept order by sum("Total Points") desc,dept)  "Global Rank"
,round(sum("Total Points"),3) "Total Points"
,round(avg("Credit Per Hr"),3) "Credit Per Hr",
round(avg("Quality Score"),3) "Quality Score",
round(avg("Stella Star Rating"),3) "Stella Star Rating",
round(avg("Schedule Adherence"),3) "Schedule Adherence",
round(avg("Inbound AHT"),3) "Inbound AHT",round(avg("Cms Defect %"),3) "Cms Defect %"
from
(
select 
to_char(a.month,'MON-YY') month ,a.ucid,a."EMPLOYEE ID",a.name,a."Team Lead",a.location,a.dept
,rank() OVER (PARTITION by a.month,a.dept ORDER BY
(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") desc,a.dept,a.month ) "Global Rank"
,(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") "Total Points"
,coalesce(a."Credit Per Hr",0) "Credit Per Hr" ,a."Credit Rank",a."Credits Score",a.CPH_TARGET
, coalesce (a."Quality Score",0)  "Quality Score"
,case when a."Quality Rank" is null then 1 else a."Quality Rank" end as "Quality Rank"
,coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0) as "Quality_Score",a.QUALITY_TARGET
,coalesce(a."Stella Star Rating",0) "Stella Star Rating"
,case when a."Stella Star Rank" is null then 1 else a."Stella Star Rank" end as "Stella Star Rank"
,coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0) as "Stella Star Score",a.STAR_TARGET
,coalesce(a."Schedule Adherence",0) "Schedule Adherence",a."Adherence Rank",a."Adherence Score",a.ADHERENCE_TARGET
,coalesce(a."Inbound AHT",0) "Inbound AHT",a."AHT Rank",a."AHT Score",a.IB_AHT_TARGET
,coalesce(a."Cms Defect %",0) "Cms Defect %" ,a."Cms Defect Rank",a."Cms Defect Score",a.CMS_DEFECT_TARGET
,a."Out Of"
from
(
select 
last_day(a.month) month,
a.ucid,
a.fusionid "EMPLOYEE ID",
a.name,
a.team_leader "Team Lead",
a.location,
a.dept
--,rank() OVER (PARTITION by last_day(a.month),a.dept ORDER BY (coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0)) desc,a.dept,last_day(a.month) ) "Global Rank"
--,(coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0))  "Total Points"
,b."Credit Per Hr",b."Credit Rank",b."Credits Score",
--b.CPH_TARGET
i.CPH_TARGET
,c."Quality Score",c."Quality Rank",c."Quality_Score"
,i.QUALITY_TARGET
,d."Stella Star Rating",d."Stella Star Rank",d."Stella Star Score"
,i.STAR_TARGET
,e."Schedule Adherence",e."Adherence Rank",e."Adherence Score"
,i.ADHERENCE_TARGET
,f."Inbound AHT",f."AHT Rank",f."AHT Score"
,i.IB_AHT_TARGET
,g."Cms Defect %",g."Cms Defect Rank",g."Cms Defect Score"
,i.CMS_DEFECT_TARGET
,h."Out Of"
from asit_roster_table a
left join(
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
--,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
,"CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
,e."CPH_TARGET"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
left join(
select month,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95","CPH_TARGET"
from (
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of"
)a )b
where "CPH_TARGET" is not null)e on last_day(a.rpt_month)=last_day(e.month) and c.dept=e.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of",e."CPH_TARGET"
)a
) b on last_day(a.month)=last_day(b.month) and a.fusionid=b.fusionid
left join(
select last_day(roster_month) month,
a.fusion_id,c.ucid,a.employee_name,c.dept
,coalesce(round(avg(score),2),0) "Quality Score"
,rank() OVER (PARTITION by last_day(roster_month),c.dept ORDER BY coalesce(round(avg(score),2),0) desc,c.dept,last_day(roster_month) )  "Quality Rank"
,b."Out Of"
,case 
when coalesce(round(avg(score),2),0) >=97.50  then 3.75 
when coalesce(round(avg(score),2),0) >=95.20  then 2.5
when coalesce(round(avg(score),2),0) >=90  then 1.25 
else 0
end as
"Quality_Score"
from asit_quality a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.roster_month)=c.month and a.fusion_id=c.fusionid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.roster_month)=b.monthn and b.dept=c.dept
--where a.roster_month=last_day('31-JAN-24') 
--and a.ucid in (select distinct ucid from asit_roster_table where fusionid='105554' ) 
group by last_day(roster_month),a.fusion_id,c.ucid,a.employee_name,c.dept,b."Out Of"

)c on last_day(a.month)=last_day(c.month) and a.fusionid=c.fusion_id
left join(
select 
last_day(a.month) month,a.employee_custom_id,c.dept
--,a.team_leader
,coalesce(round(avg(star_rating),2),0) "Stella Star Rating"
,rank() OVER (PARTITION by last_day(a.month),c.dept  ORDER BY coalesce(round(avg(star_rating),2),0) desc,c.dept ,last_day(a.month) ) "Stella Star Rank"
,b."Out Of"
,case when coalesce(round(avg(star_rating),2),0) >= 4.6 then 4.00
when coalesce(round(avg(star_rating),2),0) >= 4.5 then 3.00 
when coalesce(round(avg(star_rating),2),0) >= 4.4 then 2.00
when coalesce(round(avg(star_rating),2),0) >= 4.3 then 1.00
else 0
end as "Stella Star Score"
from asit_star_rating a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.employee_custom_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
--where  a.month=last_day(a.month)
--and employee_custom_id in ('196400') 
group by last_day(a.month),c.dept,a.employee_custom_id,b."Out Of"
)d on last_day(a.month)=last_day(d.month) and a.fusionid=d.employee_custom_id
left join (
select 
last_day(a.month) month,a.fusion_id,c.dept 
,coalesce(round(adherence_percentage*100,2),0) "Schedule Adherence"
,rank() OVER (PARTITION by last_day(a.month),c.dept ORDER BY coalesce(round(adherence_percentage*100,2),0) desc,c.dept ,last_day(a.month) ) "Adherence Rank"
,b."Out Of"
,case when coalesce(round(adherence_percentage*100,2),0) >=95 then 4.00 
when coalesce(round(adherence_percentage*100,2),0) >=92.5 then 3.00
when coalesce(round(adherence_percentage*100,2),0) >=90 then 2.00 
when coalesce(round(adherence_percentage*100,2),0) >=87.5 then 1.00
else 0
end as
"Adherence Score"
from asit_telephony a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.fusion_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)e on last_day(a.month)=last_day(e.month) and a.fusionid=e.fusion_id
left join (
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
)f on to_char(last_day(a.month),'MON-YY')=f.month and a.fusionid=f.fusionid
left join(
select 
last_day(a.month) month,c.fusionid,a.ucid,c.dept,a.cms_defect_percentage,coalesce(round(a.cms_defect_percentage*100,2),0) "Cms Defect %"
,rank() OVER (PARTITION by a.month ORDER BY coalesce(round(a.cms_defect_percentage*100,2),0) asc,a.month ) "Cms Defect Rank"
,b."Out Of"
,case when coalesce(round(a.cms_defect_percentage*100,2),0) <0.5 then 18.5 
when coalesce(round(a.cms_defect_percentage*100,2),0) <1 then 12.5
when coalesce(round(a.cms_defect_percentage*100,2),0) <=1.5 then 6.25
else 0
end as
"Cms Defect Score"
from asit_cms_defect a
join(
select month,fusionid,ucid,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.ucid=c.ucid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)g on last_day(a.month)=g.month and a.fusionid=g.fusionid
left join(
select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)h on last_day(a.month)=h.monthn and a.dept=h.dept
left join CR_SC_AGNTS_TARGET i on last_day(a.month)=i.month and a.dept=i.dept
where --a.month>=last_day(sysdate)and
 a.dept in ('CCC-R','CCC-R SPANISH','FLEX')
and a.location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and a.designation in ('Agent')
and a.final_status='ACTIVE'
and a.team_leader not in (select name from not_teamleader)
)a)b
--where  "EMPLOYEE ID" in('197233')
group by "EMPLOYEE ID",name,dept
)a
left join
(
select 
a."DEPT",
count(a."Global Rank") "Out_of"
from (
select 
"EMPLOYEE ID"
,upper(name) "EMPLOYEE_NAME"--,"Team Lead",location
,dept
,rank() OVER (order by sum("Total Points") desc)  "Global Rank"
,round(sum("Total Points"),3) "Total Points"
,round(avg("Credit Per Hr"),3) "Credit Per Hr",
round(avg("Quality Score"),3) "Quality Score",
round(avg("Stella Star Rating"),3) "Stella Star Rating",
round(avg("Schedule Adherence"),3) "Schedule Adherence",
round(avg("Inbound AHT"),3) "Inbound AHT",round(avg("Cms Defect %"),3) "Cms Defect %"
from
(
select 
to_char(a.month,'MON-YY') month ,a.ucid,a."EMPLOYEE ID",a.name,a."Team Lead",a.location,a.dept
,rank() OVER (PARTITION by a.month,a.dept ORDER BY
(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") desc,a.dept,a.month ) "Global Rank"
,(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") "Total Points"
,coalesce(a."Credit Per Hr",0) "Credit Per Hr" ,a."Credit Rank",a."Credits Score",a.CPH_TARGET
, coalesce (a."Quality Score",0)  "Quality Score"
,case when a."Quality Rank" is null then 1 else a."Quality Rank" end as "Quality Rank"
,coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0) as "Quality_Score",a.QUALITY_TARGET
,coalesce(a."Stella Star Rating",0) "Stella Star Rating"
,case when a."Stella Star Rank" is null then 1 else a."Stella Star Rank" end as "Stella Star Rank"
,coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0) as "Stella Star Score",a.STAR_TARGET
,coalesce(a."Schedule Adherence",0) "Schedule Adherence",a."Adherence Rank",a."Adherence Score",a.ADHERENCE_TARGET
,coalesce(a."Inbound AHT",0) "Inbound AHT",a."AHT Rank",a."AHT Score",a.IB_AHT_TARGET
,coalesce(a."Cms Defect %",0) "Cms Defect %" ,a."Cms Defect Rank",a."Cms Defect Score",a.CMS_DEFECT_TARGET
,a."Out Of"
from
(
select 
last_day(a.month) month,
a.ucid,
a.fusionid "EMPLOYEE ID",
a.name,
a.team_leader "Team Lead",
a.location,
a.dept
--,rank() OVER (PARTITION by last_day(a.month),a.dept ORDER BY (coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0)) desc,a.dept,last_day(a.month) ) "Global Rank"
--,(coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0))  "Total Points"
,b."Credit Per Hr",b."Credit Rank",b."Credits Score",
--b.CPH_TARGET
i.CPH_TARGET
,c."Quality Score",c."Quality Rank",c."Quality_Score"
,i.QUALITY_TARGET
,d."Stella Star Rating",d."Stella Star Rank",d."Stella Star Score"
,i.STAR_TARGET
,e."Schedule Adherence",e."Adherence Rank",e."Adherence Score"
,i.ADHERENCE_TARGET
,f."Inbound AHT",f."AHT Rank",f."AHT Score"
,i.IB_AHT_TARGET
,g."Cms Defect %",g."Cms Defect Rank",g."Cms Defect Score"
,i.CMS_DEFECT_TARGET
,h."Out Of"
from asit_roster_table a
left join(
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
--,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
,"CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
,e."CPH_TARGET"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
left join(
select month,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95","CPH_TARGET"
from (
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of"
)a )b
where "CPH_TARGET" is not null)e on last_day(a.rpt_month)=last_day(e.month) and c.dept=e.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of",e."CPH_TARGET"
)a
) b on last_day(a.month)=last_day(b.month) and a.fusionid=b.fusionid
left join(
select last_day(roster_month) month,
a.fusion_id,c.ucid,a.employee_name,c.dept
,coalesce(round(avg(score),2),0) "Quality Score"
,rank() OVER (PARTITION by last_day(roster_month),c.dept ORDER BY coalesce(round(avg(score),2),0) desc,c.dept,last_day(roster_month) )  "Quality Rank"
,b."Out Of"
,case 
when coalesce(round(avg(score),2),0) >=97.50  then 3.75 
when coalesce(round(avg(score),2),0) >=95.20  then 2.5
when coalesce(round(avg(score),2),0) >=90  then 1.25 
else 0
end as
"Quality_Score"
from asit_quality a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.roster_month)=c.month and a.fusion_id=c.fusionid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.roster_month)=b.monthn and b.dept=c.dept
--where a.roster_month=last_day('31-JAN-24') 
--and a.ucid in (select distinct ucid from asit_roster_table where fusionid='105554' ) 
group by last_day(roster_month),a.fusion_id,c.ucid,a.employee_name,c.dept,b."Out Of"

)c on last_day(a.month)=last_day(c.month) and a.fusionid=c.fusion_id
left join(
select 
last_day(a.month) month,a.employee_custom_id,c.dept
--,a.team_leader
,coalesce(round(avg(star_rating),2),0) "Stella Star Rating"
,rank() OVER (PARTITION by last_day(a.month),c.dept  ORDER BY coalesce(round(avg(star_rating),2),0) desc,c.dept ,last_day(a.month) ) "Stella Star Rank"
,b."Out Of"
,case when coalesce(round(avg(star_rating),2),0) >= 4.6 then 4.00
when coalesce(round(avg(star_rating),2),0) >= 4.5 then 3.00 
when coalesce(round(avg(star_rating),2),0) >= 4.4 then 2.00
when coalesce(round(avg(star_rating),2),0) >= 4.3 then 1.00
else 0
end as "Stella Star Score"
from asit_star_rating a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.employee_custom_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
--where  a.month=last_day(a.month)
--and employee_custom_id in ('196400') 
group by last_day(a.month),c.dept,a.employee_custom_id,b."Out Of"
)d on last_day(a.month)=last_day(d.month) and a.fusionid=d.employee_custom_id
left join (
select 
last_day(a.month) month,a.fusion_id,c.dept 
,coalesce(round(adherence_percentage*100,2),0) "Schedule Adherence"
,rank() OVER (PARTITION by last_day(a.month),c.dept ORDER BY coalesce(round(adherence_percentage*100,2),0) desc,c.dept ,last_day(a.month) ) "Adherence Rank"
,b."Out Of"
,case when coalesce(round(adherence_percentage*100,2),0) >=95 then 4.00 
when coalesce(round(adherence_percentage*100,2),0) >=92.5 then 3.00
when coalesce(round(adherence_percentage*100,2),0) >=90 then 2.00 
when coalesce(round(adherence_percentage*100,2),0) >=87.5 then 1.00
else 0
end as
"Adherence Score"
from asit_telephony a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.fusion_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)e on last_day(a.month)=last_day(e.month) and a.fusionid=e.fusion_id
left join (
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
)f on to_char(last_day(a.month),'MON-YY')=f.month and a.fusionid=f.fusionid
left join(
select 
last_day(a.month) month,c.fusionid,a.ucid,c.dept,a.cms_defect_percentage,coalesce(round(a.cms_defect_percentage*100,2),0) "Cms Defect %"
,rank() OVER (PARTITION by a.month ORDER BY coalesce(round(a.cms_defect_percentage*100,2),0) asc,a.month ) "Cms Defect Rank"
,b."Out Of"
,case when coalesce(round(a.cms_defect_percentage*100,2),0) <0.5 then 18.5 
when coalesce(round(a.cms_defect_percentage*100,2),0) <1 then 12.5
when coalesce(round(a.cms_defect_percentage*100,2),0) <=1.5 then 6.25
else 0
end as
"Cms Defect Score"
from asit_cms_defect a
join(
select month,fusionid,ucid,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.ucid=c.ucid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)g on last_day(a.month)=g.month and a.fusionid=g.fusionid
left join(
select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)h on last_day(a.month)=h.monthn and a.dept=h.dept
left join CR_SC_AGNTS_TARGET i on last_day(a.month)=i.month and a.dept=i.dept
where --a.month>=last_day(sysdate)and
 a.dept in ('CCC-R','CCC-R SPANISH','FLEX')
and a.location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and a.designation in ('Agent')
and a.final_status='ACTIVE'
and a.team_leader not in (select name from not_teamleader)
)a)b
--where  "EMPLOYEE ID" in('197233')
group by "EMPLOYEE ID",name,dept
)a
group by a.dept
)b on a.dept=b.dept
where a."EMPLOYEE ID" in (vfusionid2)
--('197043')
order by a."Global Rank"
;

end if;
 
END CR_SC_YTD_AGNTS;

  
  PROCEDURE CR_SC_MTD_TL (
    per in VARCHAR2,vfusionid3 in VARCHAR2, p_result OUT SYS_REFCURSOR) 
    is 
    period date;
  BEGIN
    -- TODO: Implementation required for PROCEDURE CR_SC_MTD_AGNTS.CR_SC_MTD_AGNTS
      period:=to_date(per,'yyyy-MM-dd');
         dbms_output.put_line('period =' || period);
         
         if(vfusionid3 is null and period is null ) then
            OPEN p_result FOR 
  select 
to_char(a."MONTH",'MON-YY') "MONTH",
a."UCID",
a."FUSION_ID" ,
a."SUPV_NAME" "TL NAME" ,
a."MANAGER_NAME" "ASM",
a."LOCATION",
a."DEPT",
a."Overall Rank" "Global Rank",
a."Overall Score" "Total Points",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Defect Rank",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Defect Rank",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of",
b."YTD Global Rank",
b."YTD Global Total Points"
from(
select 
a."MONTH",
a."FUSION_ID",
a."UCID",
a."NAME" "SUPV_NAME",
a."TEAM_LEADER" "MANAGER_NAME",
a."LOCATION",
a."DEPT",
round((coalesce( a."Res Credit Points",0)+ coalesce(a."Stella Star Points",0)+ coalesce(a."Adherence Points",0)+
coalesce(a."AHT Points",0)+coalesce(a."CMS Usage Points",0)+ coalesce(a."TL Call Monitoring Points",0)
+coalesce(a."Collection call Model Points",0)),2)  "Overall Score",
rank() OVER (PARTITION by month ORDER BY round((coalesce( a."Res Credit Points",0)+ coalesce(a."Stella Star Points",0)+ coalesce(a."Adherence Points",0)+
coalesce(a."AHT Points",0)+coalesce(a."CMS Usage Points",0)+ coalesce(a."TL Call Monitoring Points",0)
+coalesce(a."Collection call Model Points",0)),2) desc,month ) "Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Defect Rank",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Defect Rank",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from (
select 
--"EMPLOYEE ID"--,name,"Team Lead",location,dept
b.month,b.TL_FUSIONID "FUSION_ID",
c.ucid
,b."Team Lead" NAME, c.team_leader,c.location,c.dept
,round(avg(b."Credit Per Hr"),3) "Resolution Credits"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept ) "Res Credit Rank"
,case when round(avg(b."Credit Per Hr"),3) >2.000 then 
(case when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.15,0) then 11.25 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.6,0) then 7.5 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.85,0) then 3.75 
else 0 end )
else 0
end as "Res Credit Points"
,i.cph_target
--,round(avg(b."Quality Score"),2) "Quality Score"
--,i.QUALITY_TARGET
,round(avg(b."Stella Star Rating"),2) "Stella Star Rating"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Stella Star Rating"),2) desc,b.month,c.dept ) "Stella Star Rank"
, case when round(avg(b."Stella Star Rating"),2) >4.6 then  5-(5*0.20)
when round(avg(b."Stella Star Rating"),2) >=4.5 then  5-(5*0.40)
when round(avg(b."Stella Star Rating"),2) >=4.4 then  5-(5*0.60)
when round(avg(b."Stella Star Rating"),2) >=4.3 then  5-(5*0.80)
else 0 
end as "Stella Star Points"
,i.STAR_TARGET
,round(avg(b."Schedule Adherence"),2) "Schedule Adherence"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Schedule Adherence"),2) desc,b.month,c.dept ) "Adherence Rank"
, case when round(avg(b."Schedule Adherence"),3)>92.50 then 5-(5*0.20)
when round(avg(b."Schedule Adherence"),3)>=90.00 then 5-(5*0.40)
when round(avg(b."Schedule Adherence"),3)>=87.50 then 5-(5*0.60)
when round(avg(b."Schedule Adherence"),3)>=85.00 then 5-(5*0.80)
else 0 end as "Adherence Points"
,i.ADHERENCE_TARGET
,round(avg(b."Inbound AHT"),2) "Inbound AHT"
--,coalesce (j."Inbound AHT",0) "Inbound AHT"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Inbound AHT"),2) desc,b.month,c.dept ) "AHT Rank"
,case when round(avg(b."Inbound AHT"),2)>660 then 0
 when round(avg(b."Inbound AHT"),2) >=660 then 5-(5*0.80)
when round(avg(b."Inbound AHT"),2) >=630 then 5-(5*0.60)
when round(avg(b."Inbound AHT"),2) >=600 then 5-(5*0.40)
else 5-(5*0.20) end as "AHT Points"
,i.ib_aht_target
,round(avg(b."Cms Defect %"),2) "Cms Defect %"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Cms Defect %"),2) asc,b.month,c.dept ) "Cms Defect Rank"
,case when round(avg(b."Cms Defect %"),2) <0.5 then 18.75
when round(avg(b."Cms Defect %"),2) < 1.0 then 12.5
when round(avg(b."Cms Defect %"),2) <1.5 then 6.25
else 0
end as "CMS Usage Points"
,i.CMS_DEFECT_TARGET
,f.qc_per "TL Call Monitoring Defect"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY f.qc_per desc,b.month,c.dept ) "TL Call Monitoring Defect Rank"
,case when f.qc_per = 0 then  7.5
when f.qc_per <= 25 then  5
when f.qc_per <= 75 then  2.5
else 0
end as  "TL Call Monitoring Points"
,i.call_monitoring_defect_target
,e.defect_per "Collection call Model Defect"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY e.defect_per desc,b.month,c.dept ) "Collection call Model Defect Rank"
,case when e.defect_per < 1.5 then 7.5
when e.defect_per < 2.5 then 5
when e.defect_per < 3.5 then 2.5
else 0
end as "Collection call Model Points"
,i.collection_call_model_defect_target
,k."Out Of"
from
(
select 
a.month  ,a.ucid,a."EMPLOYEE ID",a.name,a.TL_FUSIONID,a."Team Lead",a.location,a.dept
,rank() OVER (PARTITION by a.month,a.dept ORDER BY
(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") desc,a.dept,a.month ) "Global Rank"
,(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") "Total Points"
,coalesce(a."Credit Per Hr",0) "Credit Per Hr" ,a."Credit Rank",a."Credits Score",a.CPH_TARGET
, coalesce (a."Quality Score",0)  "Quality Score"
,case when a."Quality Rank" is null then 1 else a."Quality Rank" end as "Quality Rank"
,coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0) as "Quality_Score",a.QUALITY_TARGET
,coalesce(a."Stella Star Rating",0) "Stella Star Rating"
,case when a."Stella Star Rank" is null then 1 else a."Stella Star Rank" end as "Stella Star Rank"
,coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0) as "Stella Star Score",a.STAR_TARGET
,coalesce(a."Schedule Adherence",0) "Schedule Adherence",a."Adherence Rank",a."Adherence Score",a.ADHERENCE_TARGET
,coalesce(a."Inbound AHT",0) "Inbound AHT",a."AHT Rank",a."AHT Score",a.IB_AHT_TARGET
,coalesce(a."Cms Defect %",0) "Cms Defect %" ,a."Cms Defect Rank",a."Cms Defect Score",a.CMS_DEFECT_TARGET
,a."Out Of"
from
(
select 
last_day(a.month) month,
a.ucid,
a.fusionid "EMPLOYEE ID",
a.name,
a.TL_FUSIONID,
a.team_leader "Team Lead",
a.location,
a.dept
--,rank() OVER (PARTITION by last_day(a.month),a.dept ORDER BY (coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0)) desc,a.dept,last_day(a.month) ) "Global Rank"
--,(coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0))  "Total Points"
,b."Credit Per Hr",b."Credit Rank",b."Credits Score",
--b.CPH_TARGET
i.CPH_TARGET
,c."Quality Score",c."Quality Rank",c."Quality_Score"
,i.QUALITY_TARGET
,d."Stella Star Rating",d."Stella Star Rank",d."Stella Star Score"
,i.STAR_TARGET
,e."Schedule Adherence",e."Adherence Rank",e."Adherence Score"
,i.ADHERENCE_TARGET
,f."Inbound AHT",f."AHT Rank",f."AHT Score"
,i.IB_AHT_TARGET
,g."Cms Defect %",g."Cms Defect Rank",g."Cms Defect Score"
,i.CMS_DEFECT_TARGET
,h."Out Of"
from asit_roster_table a
left join(
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
--,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
,"CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
,e."CPH_TARGET"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
left join(
select month,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95","CPH_TARGET"
from (
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of"
)a )b
where "CPH_TARGET" is not null)e on last_day(a.rpt_month)=last_day(e.month) and c.dept=e.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of",e."CPH_TARGET"
)a
) b on last_day(a.month)=last_day(b.month) and a.fusionid=b.fusionid
left join(
select last_day(roster_month) month,
a.fusion_id,c.ucid,a.employee_name,c.dept
,coalesce(round(avg(score),2),0) "Quality Score"
,rank() OVER (PARTITION by last_day(roster_month),c.dept ORDER BY coalesce(round(avg(score),2),0) desc,c.dept,last_day(roster_month) )  "Quality Rank"
,b."Out Of"
,case 
when coalesce(round(avg(score),2),0) >=97.50  then 3.75 
when coalesce(round(avg(score),2),0) >=95.20  then 2.5
when coalesce(round(avg(score),2),0) >=90  then 1.25 
else 0
end as
"Quality_Score"
from asit_quality a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.roster_month)=c.month and a.fusion_id=c.fusionid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.roster_month)=b.monthn and b.dept=c.dept
--where a.roster_month=last_day('31-JAN-24') 
--and a.ucid in (select distinct ucid from asit_roster_table where fusionid='105554' ) 
group by last_day(roster_month),a.fusion_id,c.ucid,a.employee_name,c.dept,b."Out Of"

)c on last_day(a.month)=last_day(c.month) and a.fusionid=c.fusion_id
left join(
select 
last_day(a.month) month,a.employee_custom_id,c.dept
--,a.team_leader
,coalesce(round(avg(star_rating),2),0) "Stella Star Rating"
,rank() OVER (PARTITION by last_day(a.month),c.dept  ORDER BY coalesce(round(avg(star_rating),2),0) desc,c.dept ,last_day(a.month) ) "Stella Star Rank"
,b."Out Of"
,case when coalesce(round(avg(star_rating),2),0) >= 4.6 then 4.00
when coalesce(round(avg(star_rating),2),0) >= 4.5 then 3.00 
when coalesce(round(avg(star_rating),2),0) >= 4.4 then 2.00
when coalesce(round(avg(star_rating),2),0) >= 4.3 then 1.00
else 0
end as "Stella Star Score"
from asit_star_rating a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.employee_custom_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
--where  a.month=last_day(a.month)
--and employee_custom_id in ('196400') 
group by last_day(a.month),c.dept,a.employee_custom_id,b."Out Of"
)d on last_day(a.month)=last_day(d.month) and a.fusionid=d.employee_custom_id
left join (
select 
last_day(a.month) month,a.fusion_id,c.dept 
,coalesce(round(adherence_percentage*100,2),0) "Schedule Adherence"
,rank() OVER (PARTITION by last_day(a.month),c.dept ORDER BY coalesce(round(adherence_percentage*100,2),0) desc,c.dept ,last_day(a.month) ) "Adherence Rank"
,b."Out Of"
,case when coalesce(round(adherence_percentage*100,2),0) >=95 then 4.00 
when coalesce(round(adherence_percentage*100,2),0) >=92.5 then 3.00
when coalesce(round(adherence_percentage*100,2),0) >=90 then 2.00 
when coalesce(round(adherence_percentage*100,2),0) >=87.5 then 1.00
else 0
end as
"Adherence Score"
from asit_telephony a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.fusion_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)e on last_day(a.month)=last_day(e.month) and a.fusionid=e.fusion_id
left join (
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
)f on to_char(last_day(a.month),'MON-YY')=f.month and a.fusionid=f.fusionid
left join(
select 
last_day(a.month) month,c.fusionid,a.ucid,c.dept,a.cms_defect_percentage,coalesce(round(a.cms_defect_percentage*100,2),0) "Cms Defect %"
,rank() OVER (PARTITION by a.month ORDER BY coalesce(round(a.cms_defect_percentage*100,2),0) asc,a.month ) "Cms Defect Rank"
,b."Out Of"
,case when coalesce(round(a.cms_defect_percentage*100,2),0) <0.5 then 18.5 
when coalesce(round(a.cms_defect_percentage*100,2),0) <1 then 12.5
when coalesce(round(a.cms_defect_percentage*100,2),0) <=1.5 then 6.25
else 0
end as
"Cms Defect Score"
from asit_cms_defect a
join(
select month,fusionid,ucid,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.ucid=c.ucid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)g on last_day(a.month)=g.month and a.fusionid=g.fusionid
left join(
select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)h on last_day(a.month)=h.monthn and a.dept=h.dept
left join CR_SC_AGNTS_TARGET i on last_day(a.month)=i.month and a.dept=i.dept
where --a.month>=last_day(sysdate)and
 a.dept in ('CCC-R','CCC-R SPANISH','FLEX')
and a.location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and a.designation in ('Agent')
and a.final_status='ACTIVE'
and a.team_leader not in (select name from not_teamleader)
)a)b
join(
select month,fusionid,ucid,name,TL_FUSIONID,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on b.month=c.month and b.TL_FUSIONID=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)d on b.month=d.monthn and c.dept=d.dept
left join (
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end defect_per 
 from asit_tl_impact
)e on b.month=e.month and b.TL_FUSIONID=e.fusionid
left join(
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end QC_per 
 from asit_tl_qc
)f on b.month=f.month and b.TL_FUSIONID=f.fusionid
left join CR_SC_TL_TARGET i on b.month=i.month and c.dept=i.dept
left join(
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept

) j on to_char(b.month,'MON-YY')=j.month and b.TL_FUSIONID=j.fusionid
left join (select 
to_char(last_day(month),'MON-YY') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-YY'),dept
)k on to_char(b.month,'MON-YY')=k.monthn and c.dept=k.dept
--where  "EMPLOYEE ID" in('197233')
group by b.month,b.TL_FUSIONID,b."Team Lead"
,c.fusionid,c.ucid, c.team_leader,c.location,c.dept,
i.cph_target,i.STAR_TARGET,i.ADHERENCE_TARGET,i.CMS_DEFECT_TARGET,i.collection_call_model_defect_target,i.call_monitoring_defect_target,i.ib_aht_target
,e.defect_per,f.QC_per,j."Inbound AHT",k."Out Of"
)a )a
left join (
select 
fusion_id,
 "YTD Global Rank",
"YTD Global Total Points"
from (
select 
a.fusion_id
,rank() OVER (order by sum(a."Overall Score") desc)  "YTD Global Rank"
,sum(a."Overall Score") "YTD Global Total Points"
from(
select 
to_char(a."MONTH",'MON-YY') "MONTH",
a."FUSION_ID",
a."UCID",
a."SUPV_NAME",
a."MANAGER_NAME",
a."LOCATION",
a."DEPT",
a."Overall Score",
a."Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from(
select 
a."MONTH",
a."FUSION_ID",
a."UCID",
a."NAME" "SUPV_NAME",
a."TEAM_LEADER" "MANAGER_NAME",
a."LOCATION",
a."DEPT",
round((a."Res Credit Points"+a."Stella Star Points"+a."Adherence Points"+a."AHT Points"+a."CMS Usage Points"
+a."TL Call Monitoring Points"+a."Collection call Model Points"),2)  "Overall Score",
rank() OVER (PARTITION by month ORDER BY round((a."Res Credit Points"+a."Stella Star Points"+a."Adherence Points"+a."AHT Points"+a."CMS Usage Points"
+a."TL Call Monitoring Points"+a."Collection call Model Points"),2) desc,month ) "Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from (
select 
--"EMPLOYEE ID"--,name,"Team Lead",location,dept
b.month,b.TL_FUSIONID "FUSION_ID",
c.ucid
,b."Team Lead" NAME, c.team_leader,c.location,c.dept
,round(avg(b."Credit Per Hr"),3) "Resolution Credits"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept ) "Res Credit Rank"
,case when round(avg(b."Credit Per Hr"),3) >2.000 then 
(case when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.15,0) then 11.25 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.6,0) then 7.5 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.85,0) then 3.75 
else 0 end )
else 0
end as "Res Credit Points"
,i.cph_target
--,round(avg(b."Quality Score"),2) "Quality Score"
--,i.QUALITY_TARGET
,round(avg(b."Stella Star Rating"),2) "Stella Star Rating"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Stella Star Rating"),2) desc,b.month,c.dept ) "Stella Star Rank"
, case when round(avg(b."Stella Star Rating"),2) >4.6 then  5-(5*0.20)
when round(avg(b."Stella Star Rating"),2) >=4.5 then  5-(5*0.40)
when round(avg(b."Stella Star Rating"),2) >=4.4 then  5-(5*0.60)
when round(avg(b."Stella Star Rating"),2) >=4.3 then  5-(5*0.80)
else 0 
end as "Stella Star Points"
,i.STAR_TARGET
,round(avg(b."Schedule Adherence"),2) "Schedule Adherence"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Schedule Adherence"),2) desc,b.month,c.dept ) "Adherence Rank"
, case when round(avg(b."Schedule Adherence"),3)>92.50 then 5-(5*0.20)
when round(avg(b."Schedule Adherence"),3)>=90.00 then 5-(5*0.40)
when round(avg(b."Schedule Adherence"),3)>=87.50 then 5-(5*0.60)
when round(avg(b."Schedule Adherence"),3)>=85.00 then 5-(5*0.80)
else 0 end as "Adherence Points"
,i.ADHERENCE_TARGET
,round(avg(b."Inbound AHT"),2) "Inbound AHT"
--,coalesce (j."Inbound AHT",0) "Inbound AHT"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Inbound AHT"),2) desc,b.month,c.dept ) "AHT Rank"
,case when round(avg(b."Inbound AHT"),2)>660 then 0
 when round(avg(b."Inbound AHT"),2) >=660 then 5-(5*0.80)
when round(avg(b."Inbound AHT"),2) >=630 then 5-(5*0.60)
when round(avg(b."Inbound AHT"),2) >=600 then 5-(5*0.40)
else 5-(5*0.20) end as "AHT Points"
,i.ib_aht_target
,round(avg(b."Cms Defect %"),2) "Cms Defect %"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Cms Defect %"),2) asc,b.month,c.dept ) "Cms Defect Rank"
,case when round(avg(b."Cms Defect %"),2) <0.5 then 18.75
when round(avg(b."Cms Defect %"),2) < 1.0 then 12.5
when round(avg(b."Cms Defect %"),2) <1.5 then 6.25
else 0
end as "CMS Usage Points"
,i.CMS_DEFECT_TARGET
,f.qc_per "TL Call Monitoring Defect"
,case when f.qc_per = 0 then  7.5
when f.qc_per <= 25 then  5
when f.qc_per <= 75 then  2.5
else 0
end as  "TL Call Monitoring Points"
,i.call_monitoring_defect_target
,e.defect_per "Collection call Model Defect"
,case when e.defect_per < 1.5 then 7.5
when e.defect_per < 2.5 then 5
when e.defect_per < 3.5 then 2.5
else 0
end as "Collection call Model Points"
,i.collection_call_model_defect_target
,k."Out Of"
from
(
select 
a.month  ,a.ucid,a."EMPLOYEE ID",a.name,a.TL_FUSIONID,a."Team Lead",a.location,a.dept
,rank() OVER (PARTITION by a.month,a.dept ORDER BY
(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") desc,a.dept,a.month ) "Global Rank"
,(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") "Total Points"
,coalesce(a."Credit Per Hr",0) "Credit Per Hr" ,a."Credit Rank",a."Credits Score",a.CPH_TARGET
, coalesce (a."Quality Score",0)  "Quality Score"
,case when a."Quality Rank" is null then 1 else a."Quality Rank" end as "Quality Rank"
,coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0) as "Quality_Score",a.QUALITY_TARGET
,coalesce(a."Stella Star Rating",0) "Stella Star Rating"
,case when a."Stella Star Rank" is null then 1 else a."Stella Star Rank" end as "Stella Star Rank"
,coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0) as "Stella Star Score",a.STAR_TARGET
,coalesce(a."Schedule Adherence",0) "Schedule Adherence",a."Adherence Rank",a."Adherence Score",a.ADHERENCE_TARGET
,coalesce(a."Inbound AHT",0) "Inbound AHT",a."AHT Rank",a."AHT Score",a.IB_AHT_TARGET
,coalesce(a."Cms Defect %",0) "Cms Defect %" ,a."Cms Defect Rank",a."Cms Defect Score",a.CMS_DEFECT_TARGET
,a."Out Of"
from
(
select 
last_day(a.month) month,
a.ucid,
a.fusionid "EMPLOYEE ID",
a.name,
a.TL_FUSIONID,
a.team_leader "Team Lead",
a.location,
a.dept
--,rank() OVER (PARTITION by last_day(a.month),a.dept ORDER BY (coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0)) desc,a.dept,last_day(a.month) ) "Global Rank"
--,(coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0))  "Total Points"
,b."Credit Per Hr",b."Credit Rank",b."Credits Score",
--b.CPH_TARGET
i.CPH_TARGET
,c."Quality Score",c."Quality Rank",c."Quality_Score"
,i.QUALITY_TARGET
,d."Stella Star Rating",d."Stella Star Rank",d."Stella Star Score"
,i.STAR_TARGET
,e."Schedule Adherence",e."Adherence Rank",e."Adherence Score"
,i.ADHERENCE_TARGET
,f."Inbound AHT",f."AHT Rank",f."AHT Score"
,i.IB_AHT_TARGET
,g."Cms Defect %",g."Cms Defect Rank",g."Cms Defect Score"
,i.CMS_DEFECT_TARGET
,h."Out Of"
from asit_roster_table a
left join(
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
--,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
,"CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
,e."CPH_TARGET"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
left join(
select month,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95","CPH_TARGET"
from (
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of"
)a )b
where "CPH_TARGET" is not null)e on last_day(a.rpt_month)=last_day(e.month) and c.dept=e.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of",e."CPH_TARGET"
)a
) b on last_day(a.month)=last_day(b.month) and a.fusionid=b.fusionid
left join(
select last_day(roster_month) month,
a.fusion_id,c.ucid,a.employee_name,c.dept
,coalesce(round(avg(score),2),0) "Quality Score"
,rank() OVER (PARTITION by last_day(roster_month),c.dept ORDER BY coalesce(round(avg(score),2),0) desc,c.dept,last_day(roster_month) )  "Quality Rank"
,b."Out Of"
,case 
when coalesce(round(avg(score),2),0) >=97.50  then 3.75 
when coalesce(round(avg(score),2),0) >=95.20  then 2.5
when coalesce(round(avg(score),2),0) >=90  then 1.25 
else 0
end as
"Quality_Score"
from asit_quality a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.roster_month)=c.month and a.fusion_id=c.fusionid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.roster_month)=b.monthn and b.dept=c.dept
--where a.roster_month=last_day('31-JAN-24') 
--and a.ucid in (select distinct ucid from asit_roster_table where fusionid='105554' ) 
group by last_day(roster_month),a.fusion_id,c.ucid,a.employee_name,c.dept,b."Out Of"

)c on last_day(a.month)=last_day(c.month) and a.fusionid=c.fusion_id
left join(
select 
last_day(a.month) month,a.employee_custom_id,c.dept
--,a.team_leader
,coalesce(round(avg(star_rating),2),0) "Stella Star Rating"
,rank() OVER (PARTITION by last_day(a.month),c.dept  ORDER BY coalesce(round(avg(star_rating),2),0) desc,c.dept ,last_day(a.month) ) "Stella Star Rank"
,b."Out Of"
,case when coalesce(round(avg(star_rating),2),0) >= 4.6 then 4.00
when coalesce(round(avg(star_rating),2),0) >= 4.5 then 3.00 
when coalesce(round(avg(star_rating),2),0) >= 4.4 then 2.00
when coalesce(round(avg(star_rating),2),0) >= 4.3 then 1.00
else 0
end as "Stella Star Score"
from asit_star_rating a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.employee_custom_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
--where  a.month=last_day(a.month)
--and employee_custom_id in ('196400') 
group by last_day(a.month),c.dept,a.employee_custom_id,b."Out Of"
)d on last_day(a.month)=last_day(d.month) and a.fusionid=d.employee_custom_id
left join (
select 
last_day(a.month) month,a.fusion_id,c.dept 
,coalesce(round(adherence_percentage*100,2),0) "Schedule Adherence"
,rank() OVER (PARTITION by last_day(a.month),c.dept ORDER BY coalesce(round(adherence_percentage*100,2),0) desc,c.dept ,last_day(a.month) ) "Adherence Rank"
,b."Out Of"
,case when coalesce(round(adherence_percentage*100,2),0) >=95 then 4.00 
when coalesce(round(adherence_percentage*100,2),0) >=92.5 then 3.00
when coalesce(round(adherence_percentage*100,2),0) >=90 then 2.00 
when coalesce(round(adherence_percentage*100,2),0) >=87.5 then 1.00
else 0
end as
"Adherence Score"
from asit_telephony a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.fusion_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)e on last_day(a.month)=last_day(e.month) and a.fusionid=e.fusion_id
left join (
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
)f on to_char(last_day(a.month),'MON-YY')=f.month and a.fusionid=f.fusionid
left join(
select 
last_day(a.month) month,c.fusionid,a.ucid,c.dept,a.cms_defect_percentage,coalesce(round(a.cms_defect_percentage*100,2),0) "Cms Defect %"
,rank() OVER (PARTITION by a.month ORDER BY coalesce(round(a.cms_defect_percentage*100,2),0) asc,a.month ) "Cms Defect Rank"
,b."Out Of"
,case when coalesce(round(a.cms_defect_percentage*100,2),0) <0.5 then 18.5 
when coalesce(round(a.cms_defect_percentage*100,2),0) <1 then 12.5
when coalesce(round(a.cms_defect_percentage*100,2),0) <=1.5 then 6.25
else 0
end as
"Cms Defect Score"
from asit_cms_defect a
join(
select month,fusionid,ucid,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.ucid=c.ucid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)g on last_day(a.month)=g.month and a.fusionid=g.fusionid
left join(
select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)h on last_day(a.month)=h.monthn and a.dept=h.dept
left join CR_SC_AGNTS_TARGET i on last_day(a.month)=i.month and a.dept=i.dept
where --a.month>=last_day(sysdate)and
 a.dept in ('CCC-R','CCC-R SPANISH','FLEX')
and a.location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and a.designation in ('Agent')
and a.final_status='ACTIVE'
and a.team_leader not in (select name from not_teamleader)
)a)b
join(
select month,fusionid,ucid,name,TL_FUSIONID,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on b.month=c.month and b.TL_FUSIONID=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)d on b.month=d.monthn and c.dept=d.dept
left join (
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end defect_per 
 from asit_tl_impact
)e on b.month=e.month and b.TL_FUSIONID=e.fusionid
left join(
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end QC_per 
 from asit_tl_qc
)f on b.month=f.month and b.TL_FUSIONID=f.fusionid
left join CR_SC_TL_TARGET i on b.month=i.month and c.dept=i.dept
left join(
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept

) j on to_char(b.month,'MON-YY')=j.month and b.TL_FUSIONID=j.fusionid
left join (select 
to_char(last_day(month),'MON-YY') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-YY'),dept
)k on to_char(b.month,'MON-YY')=k.monthn and c.dept=k.dept
--where  "EMPLOYEE ID" in('197233')
group by b.month,b.TL_FUSIONID,b."Team Lead"
,c.fusionid,c.ucid, c.team_leader,c.location,c.dept,
i.cph_target,i.STAR_TARGET,i.ADHERENCE_TARGET,i.CMS_DEFECT_TARGET,i.collection_call_model_defect_target,i.call_monitoring_defect_target,i.ib_aht_target
,e.defect_per,f.QC_per,j."Inbound AHT",k."Out Of"
)a )a)a
--where month>=last_day('01-JAN_24')
--where a."FUSION_ID" in ('195869')
group by a.fusion_id
)a 
) b on a.FUSION_ID=b.FUSION_ID
--where month>=last_day('01-JAN_24')
--where a."FUSION_ID" in ('195869')
order by a.month asc;          


 elsif (vfusionid3 is null) then
            OPEN p_result FOR
            
select 
to_char(a."MONTH",'MON-YY') "MONTH",
a."UCID",
a."FUSION_ID" ,
a."SUPV_NAME" "TL NAME" ,
a."MANAGER_NAME" "ASM",
a."LOCATION",
a."DEPT",
a."Overall Rank" "Global Rank",
a."Overall Score" "Total Points",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Defect Rank",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Defect Rank",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of",
b."YTD Global Rank",
b."YTD Global Total Points"
from(
select 
a."MONTH",
a."FUSION_ID",
a."UCID",
a."NAME" "SUPV_NAME",
a."TEAM_LEADER" "MANAGER_NAME",
a."LOCATION",
a."DEPT",
round((coalesce( a."Res Credit Points",0)+ coalesce(a."Stella Star Points",0)+ coalesce(a."Adherence Points",0)+
coalesce(a."AHT Points",0)+coalesce(a."CMS Usage Points",0)+ coalesce(a."TL Call Monitoring Points",0)
+coalesce(a."Collection call Model Points",0)),2)  "Overall Score",
rank() OVER (PARTITION by month ORDER BY round((coalesce( a."Res Credit Points",0)+ coalesce(a."Stella Star Points",0)+ coalesce(a."Adherence Points",0)+
coalesce(a."AHT Points",0)+coalesce(a."CMS Usage Points",0)+ coalesce(a."TL Call Monitoring Points",0)
+coalesce(a."Collection call Model Points",0)),2) desc,month ) "Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Defect Rank",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Defect Rank",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from (
select 
--"EMPLOYEE ID"--,name,"Team Lead",location,dept
b.month,b.TL_FUSIONID "FUSION_ID",
c.ucid
,b."Team Lead" NAME, c.team_leader,c.location,c.dept
,round(avg(b."Credit Per Hr"),3) "Resolution Credits"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept ) "Res Credit Rank"
,case when round(avg(b."Credit Per Hr"),3) >2.000 then 
(case when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.15,0) then 11.25 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.6,0) then 7.5 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.85,0) then 3.75 
else 0 end )
else 0
end as "Res Credit Points"
,i.cph_target
--,round(avg(b."Quality Score"),2) "Quality Score"
--,i.QUALITY_TARGET
,round(avg(b."Stella Star Rating"),2) "Stella Star Rating"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Stella Star Rating"),2) desc,b.month,c.dept ) "Stella Star Rank"
, case when round(avg(b."Stella Star Rating"),2) >4.6 then  5-(5*0.20)
when round(avg(b."Stella Star Rating"),2) >=4.5 then  5-(5*0.40)
when round(avg(b."Stella Star Rating"),2) >=4.4 then  5-(5*0.60)
when round(avg(b."Stella Star Rating"),2) >=4.3 then  5-(5*0.80)
else 0 
end as "Stella Star Points"
,i.STAR_TARGET
,round(avg(b."Schedule Adherence"),2) "Schedule Adherence"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Schedule Adherence"),2) desc,b.month,c.dept ) "Adherence Rank"
, case when round(avg(b."Schedule Adherence"),3)>92.50 then 5-(5*0.20)
when round(avg(b."Schedule Adherence"),3)>=90.00 then 5-(5*0.40)
when round(avg(b."Schedule Adherence"),3)>=87.50 then 5-(5*0.60)
when round(avg(b."Schedule Adherence"),3)>=85.00 then 5-(5*0.80)
else 0 end as "Adherence Points"
,i.ADHERENCE_TARGET
,round(avg(b."Inbound AHT"),2) "Inbound AHT"
--,coalesce (j."Inbound AHT",0) "Inbound AHT"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Inbound AHT"),2) desc,b.month,c.dept ) "AHT Rank"
,case when round(avg(b."Inbound AHT"),2)>660 then 0
 when round(avg(b."Inbound AHT"),2) >=660 then 5-(5*0.80)
when round(avg(b."Inbound AHT"),2) >=630 then 5-(5*0.60)
when round(avg(b."Inbound AHT"),2) >=600 then 5-(5*0.40)
else 5-(5*0.20) end as "AHT Points"
,i.ib_aht_target
,round(avg(b."Cms Defect %"),2) "Cms Defect %"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Cms Defect %"),2) asc,b.month,c.dept ) "Cms Defect Rank"
,case when round(avg(b."Cms Defect %"),2) <0.5 then 18.75
when round(avg(b."Cms Defect %"),2) < 1.0 then 12.5
when round(avg(b."Cms Defect %"),2) <1.5 then 6.25
else 0
end as "CMS Usage Points"
,i.CMS_DEFECT_TARGET
,f.qc_per "TL Call Monitoring Defect"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY f.qc_per desc,b.month,c.dept ) "TL Call Monitoring Defect Rank"
,case when f.qc_per = 0 then  7.5
when f.qc_per <= 25 then  5
when f.qc_per <= 75 then  2.5
else 0
end as  "TL Call Monitoring Points"
,i.call_monitoring_defect_target
,e.defect_per "Collection call Model Defect"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY e.defect_per desc,b.month,c.dept ) "Collection call Model Defect Rank"
,case when e.defect_per < 1.5 then 7.5
when e.defect_per < 2.5 then 5
when e.defect_per < 3.5 then 2.5
else 0
end as "Collection call Model Points"
,i.collection_call_model_defect_target
,k."Out Of"
from
(
select 
a.month  ,a.ucid,a."EMPLOYEE ID",a.name,a.TL_FUSIONID,a."Team Lead",a.location,a.dept
,rank() OVER (PARTITION by a.month,a.dept ORDER BY
(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") desc,a.dept,a.month ) "Global Rank"
,(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") "Total Points"
,coalesce(a."Credit Per Hr",0) "Credit Per Hr" ,a."Credit Rank",a."Credits Score",a.CPH_TARGET
, coalesce (a."Quality Score",0)  "Quality Score"
,case when a."Quality Rank" is null then 1 else a."Quality Rank" end as "Quality Rank"
,coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0) as "Quality_Score",a.QUALITY_TARGET
,coalesce(a."Stella Star Rating",0) "Stella Star Rating"
,case when a."Stella Star Rank" is null then 1 else a."Stella Star Rank" end as "Stella Star Rank"
,coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0) as "Stella Star Score",a.STAR_TARGET
,coalesce(a."Schedule Adherence",0) "Schedule Adherence",a."Adherence Rank",a."Adherence Score",a.ADHERENCE_TARGET
,coalesce(a."Inbound AHT",0) "Inbound AHT",a."AHT Rank",a."AHT Score",a.IB_AHT_TARGET
,coalesce(a."Cms Defect %",0) "Cms Defect %" ,a."Cms Defect Rank",a."Cms Defect Score",a.CMS_DEFECT_TARGET
,a."Out Of"
from
(
select 
last_day(a.month) month,
a.ucid,
a.fusionid "EMPLOYEE ID",
a.name,
a.TL_FUSIONID,
a.team_leader "Team Lead",
a.location,
a.dept
--,rank() OVER (PARTITION by last_day(a.month),a.dept ORDER BY (coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0)) desc,a.dept,last_day(a.month) ) "Global Rank"
--,(coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0))  "Total Points"
,b."Credit Per Hr",b."Credit Rank",b."Credits Score",
--b.CPH_TARGET
i.CPH_TARGET
,c."Quality Score",c."Quality Rank",c."Quality_Score"
,i.QUALITY_TARGET
,d."Stella Star Rating",d."Stella Star Rank",d."Stella Star Score"
,i.STAR_TARGET
,e."Schedule Adherence",e."Adherence Rank",e."Adherence Score"
,i.ADHERENCE_TARGET
,f."Inbound AHT",f."AHT Rank",f."AHT Score"
,i.IB_AHT_TARGET
,g."Cms Defect %",g."Cms Defect Rank",g."Cms Defect Score"
,i.CMS_DEFECT_TARGET
,h."Out Of"
from asit_roster_table a
left join(
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
--,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
,"CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
,e."CPH_TARGET"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
left join(
select month,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95","CPH_TARGET"
from (
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of"
)a )b
where "CPH_TARGET" is not null)e on last_day(a.rpt_month)=last_day(e.month) and c.dept=e.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of",e."CPH_TARGET"
)a
) b on last_day(a.month)=last_day(b.month) and a.fusionid=b.fusionid
left join(
select last_day(roster_month) month,
a.fusion_id,c.ucid,a.employee_name,c.dept
,coalesce(round(avg(score),2),0) "Quality Score"
,rank() OVER (PARTITION by last_day(roster_month),c.dept ORDER BY coalesce(round(avg(score),2),0) desc,c.dept,last_day(roster_month) )  "Quality Rank"
,b."Out Of"
,case 
when coalesce(round(avg(score),2),0) >=97.50  then 3.75 
when coalesce(round(avg(score),2),0) >=95.20  then 2.5
when coalesce(round(avg(score),2),0) >=90  then 1.25 
else 0
end as
"Quality_Score"
from asit_quality a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.roster_month)=c.month and a.fusion_id=c.fusionid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.roster_month)=b.monthn and b.dept=c.dept
--where a.roster_month=last_day('31-JAN-24') 
--and a.ucid in (select distinct ucid from asit_roster_table where fusionid='105554' ) 
group by last_day(roster_month),a.fusion_id,c.ucid,a.employee_name,c.dept,b."Out Of"

)c on last_day(a.month)=last_day(c.month) and a.fusionid=c.fusion_id
left join(
select 
last_day(a.month) month,a.employee_custom_id,c.dept
--,a.team_leader
,coalesce(round(avg(star_rating),2),0) "Stella Star Rating"
,rank() OVER (PARTITION by last_day(a.month),c.dept  ORDER BY coalesce(round(avg(star_rating),2),0) desc,c.dept ,last_day(a.month) ) "Stella Star Rank"
,b."Out Of"
,case when coalesce(round(avg(star_rating),2),0) >= 4.6 then 4.00
when coalesce(round(avg(star_rating),2),0) >= 4.5 then 3.00 
when coalesce(round(avg(star_rating),2),0) >= 4.4 then 2.00
when coalesce(round(avg(star_rating),2),0) >= 4.3 then 1.00
else 0
end as "Stella Star Score"
from asit_star_rating a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.employee_custom_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
--where  a.month=last_day(a.month)
--and employee_custom_id in ('196400') 
group by last_day(a.month),c.dept,a.employee_custom_id,b."Out Of"
)d on last_day(a.month)=last_day(d.month) and a.fusionid=d.employee_custom_id
left join (
select 
last_day(a.month) month,a.fusion_id,c.dept 
,coalesce(round(adherence_percentage*100,2),0) "Schedule Adherence"
,rank() OVER (PARTITION by last_day(a.month),c.dept ORDER BY coalesce(round(adherence_percentage*100,2),0) desc,c.dept ,last_day(a.month) ) "Adherence Rank"
,b."Out Of"
,case when coalesce(round(adherence_percentage*100,2),0) >=95 then 4.00 
when coalesce(round(adherence_percentage*100,2),0) >=92.5 then 3.00
when coalesce(round(adherence_percentage*100,2),0) >=90 then 2.00 
when coalesce(round(adherence_percentage*100,2),0) >=87.5 then 1.00
else 0
end as
"Adherence Score"
from asit_telephony a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.fusion_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)e on last_day(a.month)=last_day(e.month) and a.fusionid=e.fusion_id
left join (
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
)f on to_char(last_day(a.month),'MON-YY')=f.month and a.fusionid=f.fusionid
left join(
select 
last_day(a.month) month,c.fusionid,a.ucid,c.dept,a.cms_defect_percentage,coalesce(round(a.cms_defect_percentage*100,2),0) "Cms Defect %"
,rank() OVER (PARTITION by a.month ORDER BY coalesce(round(a.cms_defect_percentage*100,2),0) asc,a.month ) "Cms Defect Rank"
,b."Out Of"
,case when coalesce(round(a.cms_defect_percentage*100,2),0) <0.5 then 18.5 
when coalesce(round(a.cms_defect_percentage*100,2),0) <1 then 12.5
when coalesce(round(a.cms_defect_percentage*100,2),0) <=1.5 then 6.25
else 0
end as
"Cms Defect Score"
from asit_cms_defect a
join(
select month,fusionid,ucid,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.ucid=c.ucid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)g on last_day(a.month)=g.month and a.fusionid=g.fusionid
left join(
select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)h on last_day(a.month)=h.monthn and a.dept=h.dept
left join CR_SC_AGNTS_TARGET i on last_day(a.month)=i.month and a.dept=i.dept
where --a.month>=last_day(sysdate)and
 a.dept in ('CCC-R','CCC-R SPANISH','FLEX')
and a.location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and a.designation in ('Agent')
and a.final_status='ACTIVE'
and a.team_leader not in (select name from not_teamleader)
)a)b
join(
select month,fusionid,ucid,name,TL_FUSIONID,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on b.month=c.month and b.TL_FUSIONID=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)d on b.month=d.monthn and c.dept=d.dept
left join (
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end defect_per 
 from asit_tl_impact
)e on b.month=e.month and b.TL_FUSIONID=e.fusionid
left join(
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end QC_per 
 from asit_tl_qc
)f on b.month=f.month and b.TL_FUSIONID=f.fusionid
left join CR_SC_TL_TARGET i on b.month=i.month and c.dept=i.dept
left join(
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept

) j on to_char(b.month,'MON-YY')=j.month and b.TL_FUSIONID=j.fusionid
left join (select 
to_char(last_day(month),'MON-YY') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-YY'),dept
)k on to_char(b.month,'MON-YY')=k.monthn and c.dept=k.dept
--where  "EMPLOYEE ID" in('197233')
group by b.month,b.TL_FUSIONID,b."Team Lead"
,c.fusionid,c.ucid, c.team_leader,c.location,c.dept,
i.cph_target,i.STAR_TARGET,i.ADHERENCE_TARGET,i.CMS_DEFECT_TARGET,i.collection_call_model_defect_target,i.call_monitoring_defect_target,i.ib_aht_target
,e.defect_per,f.QC_per,j."Inbound AHT",k."Out Of"
)a )a
left join (
select 
fusion_id,
 "YTD Global Rank",
"YTD Global Total Points"
from (
select 
a.fusion_id
,rank() OVER (order by sum(a."Overall Score") desc)  "YTD Global Rank"
,sum(a."Overall Score") "YTD Global Total Points"
from(
select 
to_char(a."MONTH",'MON-YY') "MONTH",
a."FUSION_ID",
a."UCID",
a."SUPV_NAME",
a."MANAGER_NAME",
a."LOCATION",
a."DEPT",
a."Overall Score",
a."Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from(
select 
a."MONTH",
a."FUSION_ID",
a."UCID",
a."NAME" "SUPV_NAME",
a."TEAM_LEADER" "MANAGER_NAME",
a."LOCATION",
a."DEPT",
round((a."Res Credit Points"+a."Stella Star Points"+a."Adherence Points"+a."AHT Points"+a."CMS Usage Points"
+a."TL Call Monitoring Points"+a."Collection call Model Points"),2)  "Overall Score",
rank() OVER (PARTITION by month ORDER BY round((a."Res Credit Points"+a."Stella Star Points"+a."Adherence Points"+a."AHT Points"+a."CMS Usage Points"
+a."TL Call Monitoring Points"+a."Collection call Model Points"),2) desc,month ) "Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from (
select 
--"EMPLOYEE ID"--,name,"Team Lead",location,dept
b.month,b.TL_FUSIONID "FUSION_ID",
c.ucid
,b."Team Lead" NAME, c.team_leader,c.location,c.dept
,round(avg(b."Credit Per Hr"),3) "Resolution Credits"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept ) "Res Credit Rank"
,case when round(avg(b."Credit Per Hr"),3) >2.000 then 
(case when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.15,0) then 11.25 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.6,0) then 7.5 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.85,0) then 3.75 
else 0 end )
else 0
end as "Res Credit Points"
,i.cph_target
--,round(avg(b."Quality Score"),2) "Quality Score"
--,i.QUALITY_TARGET
,round(avg(b."Stella Star Rating"),2) "Stella Star Rating"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Stella Star Rating"),2) desc,b.month,c.dept ) "Stella Star Rank"
, case when round(avg(b."Stella Star Rating"),2) >4.6 then  5-(5*0.20)
when round(avg(b."Stella Star Rating"),2) >=4.5 then  5-(5*0.40)
when round(avg(b."Stella Star Rating"),2) >=4.4 then  5-(5*0.60)
when round(avg(b."Stella Star Rating"),2) >=4.3 then  5-(5*0.80)
else 0 
end as "Stella Star Points"
,i.STAR_TARGET
,round(avg(b."Schedule Adherence"),2) "Schedule Adherence"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Schedule Adherence"),2) desc,b.month,c.dept ) "Adherence Rank"
, case when round(avg(b."Schedule Adherence"),3)>92.50 then 5-(5*0.20)
when round(avg(b."Schedule Adherence"),3)>=90.00 then 5-(5*0.40)
when round(avg(b."Schedule Adherence"),3)>=87.50 then 5-(5*0.60)
when round(avg(b."Schedule Adherence"),3)>=85.00 then 5-(5*0.80)
else 0 end as "Adherence Points"
,i.ADHERENCE_TARGET
,round(avg(b."Inbound AHT"),2) "Inbound AHT"
--,coalesce (j."Inbound AHT",0) "Inbound AHT"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Inbound AHT"),2) desc,b.month,c.dept ) "AHT Rank"
,case when round(avg(b."Inbound AHT"),2)>660 then 0
 when round(avg(b."Inbound AHT"),2) >=660 then 5-(5*0.80)
when round(avg(b."Inbound AHT"),2) >=630 then 5-(5*0.60)
when round(avg(b."Inbound AHT"),2) >=600 then 5-(5*0.40)
else 5-(5*0.20) end as "AHT Points"
,i.ib_aht_target
,round(avg(b."Cms Defect %"),2) "Cms Defect %"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Cms Defect %"),2) asc,b.month,c.dept ) "Cms Defect Rank"
,case when round(avg(b."Cms Defect %"),2) <0.5 then 18.75
when round(avg(b."Cms Defect %"),2) < 1.0 then 12.5
when round(avg(b."Cms Defect %"),2) <1.5 then 6.25
else 0
end as "CMS Usage Points"
,i.CMS_DEFECT_TARGET
,f.qc_per "TL Call Monitoring Defect"
,case when f.qc_per = 0 then  7.5
when f.qc_per <= 25 then  5
when f.qc_per <= 75 then  2.5
else 0
end as  "TL Call Monitoring Points"
,i.call_monitoring_defect_target
,e.defect_per "Collection call Model Defect"
,case when e.defect_per < 1.5 then 7.5
when e.defect_per < 2.5 then 5
when e.defect_per < 3.5 then 2.5
else 0
end as "Collection call Model Points"
,i.collection_call_model_defect_target
,k."Out Of"
from
(
select 
a.month  ,a.ucid,a."EMPLOYEE ID",a.name,a.TL_FUSIONID,a."Team Lead",a.location,a.dept
,rank() OVER (PARTITION by a.month,a.dept ORDER BY
(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") desc,a.dept,a.month ) "Global Rank"
,(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") "Total Points"
,coalesce(a."Credit Per Hr",0) "Credit Per Hr" ,a."Credit Rank",a."Credits Score",a.CPH_TARGET
, coalesce (a."Quality Score",0)  "Quality Score"
,case when a."Quality Rank" is null then 1 else a."Quality Rank" end as "Quality Rank"
,coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0) as "Quality_Score",a.QUALITY_TARGET
,coalesce(a."Stella Star Rating",0) "Stella Star Rating"
,case when a."Stella Star Rank" is null then 1 else a."Stella Star Rank" end as "Stella Star Rank"
,coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0) as "Stella Star Score",a.STAR_TARGET
,coalesce(a."Schedule Adherence",0) "Schedule Adherence",a."Adherence Rank",a."Adherence Score",a.ADHERENCE_TARGET
,coalesce(a."Inbound AHT",0) "Inbound AHT",a."AHT Rank",a."AHT Score",a.IB_AHT_TARGET
,coalesce(a."Cms Defect %",0) "Cms Defect %" ,a."Cms Defect Rank",a."Cms Defect Score",a.CMS_DEFECT_TARGET
,a."Out Of"
from
(
select 
last_day(a.month) month,
a.ucid,
a.fusionid "EMPLOYEE ID",
a.name,
a.TL_FUSIONID,
a.team_leader "Team Lead",
a.location,
a.dept
--,rank() OVER (PARTITION by last_day(a.month),a.dept ORDER BY (coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0)) desc,a.dept,last_day(a.month) ) "Global Rank"
--,(coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0))  "Total Points"
,b."Credit Per Hr",b."Credit Rank",b."Credits Score",
--b.CPH_TARGET
i.CPH_TARGET
,c."Quality Score",c."Quality Rank",c."Quality_Score"
,i.QUALITY_TARGET
,d."Stella Star Rating",d."Stella Star Rank",d."Stella Star Score"
,i.STAR_TARGET
,e."Schedule Adherence",e."Adherence Rank",e."Adherence Score"
,i.ADHERENCE_TARGET
,f."Inbound AHT",f."AHT Rank",f."AHT Score"
,i.IB_AHT_TARGET
,g."Cms Defect %",g."Cms Defect Rank",g."Cms Defect Score"
,i.CMS_DEFECT_TARGET
,h."Out Of"
from asit_roster_table a
left join(
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
--,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
,"CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
,e."CPH_TARGET"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
left join(
select month,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95","CPH_TARGET"
from (
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of"
)a )b
where "CPH_TARGET" is not null)e on last_day(a.rpt_month)=last_day(e.month) and c.dept=e.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of",e."CPH_TARGET"
)a
) b on last_day(a.month)=last_day(b.month) and a.fusionid=b.fusionid
left join(
select last_day(roster_month) month,
a.fusion_id,c.ucid,a.employee_name,c.dept
,coalesce(round(avg(score),2),0) "Quality Score"
,rank() OVER (PARTITION by last_day(roster_month),c.dept ORDER BY coalesce(round(avg(score),2),0) desc,c.dept,last_day(roster_month) )  "Quality Rank"
,b."Out Of"
,case 
when coalesce(round(avg(score),2),0) >=97.50  then 3.75 
when coalesce(round(avg(score),2),0) >=95.20  then 2.5
when coalesce(round(avg(score),2),0) >=90  then 1.25 
else 0
end as
"Quality_Score"
from asit_quality a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.roster_month)=c.month and a.fusion_id=c.fusionid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.roster_month)=b.monthn and b.dept=c.dept
--where a.roster_month=last_day('31-JAN-24') 
--and a.ucid in (select distinct ucid from asit_roster_table where fusionid='105554' ) 
group by last_day(roster_month),a.fusion_id,c.ucid,a.employee_name,c.dept,b."Out Of"

)c on last_day(a.month)=last_day(c.month) and a.fusionid=c.fusion_id
left join(
select 
last_day(a.month) month,a.employee_custom_id,c.dept
--,a.team_leader
,coalesce(round(avg(star_rating),2),0) "Stella Star Rating"
,rank() OVER (PARTITION by last_day(a.month),c.dept  ORDER BY coalesce(round(avg(star_rating),2),0) desc,c.dept ,last_day(a.month) ) "Stella Star Rank"
,b."Out Of"
,case when coalesce(round(avg(star_rating),2),0) >= 4.6 then 4.00
when coalesce(round(avg(star_rating),2),0) >= 4.5 then 3.00 
when coalesce(round(avg(star_rating),2),0) >= 4.4 then 2.00
when coalesce(round(avg(star_rating),2),0) >= 4.3 then 1.00
else 0
end as "Stella Star Score"
from asit_star_rating a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.employee_custom_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
--where  a.month=last_day(a.month)
--and employee_custom_id in ('196400') 
group by last_day(a.month),c.dept,a.employee_custom_id,b."Out Of"
)d on last_day(a.month)=last_day(d.month) and a.fusionid=d.employee_custom_id
left join (
select 
last_day(a.month) month,a.fusion_id,c.dept 
,coalesce(round(adherence_percentage*100,2),0) "Schedule Adherence"
,rank() OVER (PARTITION by last_day(a.month),c.dept ORDER BY coalesce(round(adherence_percentage*100,2),0) desc,c.dept ,last_day(a.month) ) "Adherence Rank"
,b."Out Of"
,case when coalesce(round(adherence_percentage*100,2),0) >=95 then 4.00 
when coalesce(round(adherence_percentage*100,2),0) >=92.5 then 3.00
when coalesce(round(adherence_percentage*100,2),0) >=90 then 2.00 
when coalesce(round(adherence_percentage*100,2),0) >=87.5 then 1.00
else 0
end as
"Adherence Score"
from asit_telephony a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.fusion_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)e on last_day(a.month)=last_day(e.month) and a.fusionid=e.fusion_id
left join (
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
)f on to_char(last_day(a.month),'MON-YY')=f.month and a.fusionid=f.fusionid
left join(
select 
last_day(a.month) month,c.fusionid,a.ucid,c.dept,a.cms_defect_percentage,coalesce(round(a.cms_defect_percentage*100,2),0) "Cms Defect %"
,rank() OVER (PARTITION by a.month ORDER BY coalesce(round(a.cms_defect_percentage*100,2),0) asc,a.month ) "Cms Defect Rank"
,b."Out Of"
,case when coalesce(round(a.cms_defect_percentage*100,2),0) <0.5 then 18.5 
when coalesce(round(a.cms_defect_percentage*100,2),0) <1 then 12.5
when coalesce(round(a.cms_defect_percentage*100,2),0) <=1.5 then 6.25
else 0
end as
"Cms Defect Score"
from asit_cms_defect a
join(
select month,fusionid,ucid,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.ucid=c.ucid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)g on last_day(a.month)=g.month and a.fusionid=g.fusionid
left join(
select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)h on last_day(a.month)=h.monthn and a.dept=h.dept
left join CR_SC_AGNTS_TARGET i on last_day(a.month)=i.month and a.dept=i.dept
where --a.month>=last_day(sysdate)and
 a.dept in ('CCC-R','CCC-R SPANISH','FLEX')
and a.location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and a.designation in ('Agent')
and a.final_status='ACTIVE'
and a.team_leader not in (select name from not_teamleader)
)a)b
join(
select month,fusionid,ucid,name,TL_FUSIONID,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on b.month=c.month and b.TL_FUSIONID=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)d on b.month=d.monthn and c.dept=d.dept
left join (
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end defect_per 
 from asit_tl_impact
)e on b.month=e.month and b.TL_FUSIONID=e.fusionid
left join(
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end QC_per 
 from asit_tl_qc
)f on b.month=f.month and b.TL_FUSIONID=f.fusionid
left join CR_SC_TL_TARGET i on b.month=i.month and c.dept=i.dept
left join(
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept

) j on to_char(b.month,'MON-YY')=j.month and b.TL_FUSIONID=j.fusionid
left join (select 
to_char(last_day(month),'MON-YY') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-YY'),dept
)k on to_char(b.month,'MON-YY')=k.monthn and c.dept=k.dept
--where  "EMPLOYEE ID" in('197233')
group by b.month,b.TL_FUSIONID,b."Team Lead"
,c.fusionid,c.ucid, c.team_leader,c.location,c.dept,
i.cph_target,i.STAR_TARGET,i.ADHERENCE_TARGET,i.CMS_DEFECT_TARGET,i.collection_call_model_defect_target,i.call_monitoring_defect_target,i.ib_aht_target
,e.defect_per,f.QC_per,j."Inbound AHT",k."Out Of"
)a )a)a
--where month>=last_day('01-JAN_24')
--where a."FUSION_ID" in ('195869')
group by a.fusion_id
)a 
) b on a.FUSION_ID=b.FUSION_ID
where month>=last_day(period)
--where a."FUSION_ID" in ('195869')
order by a.month asc;

 elsif (period is null) then
            OPEN p_result FOR

select 
to_char(a."MONTH",'MON-YY') "MONTH",
a."UCID",
a."FUSION_ID" ,
a."SUPV_NAME" "TL NAME" ,
a."MANAGER_NAME" "ASM",
a."LOCATION",
a."DEPT",
a."Overall Rank" "Global Rank",
a."Overall Score" "Total Points",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Defect Rank",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Defect Rank",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of",
b."YTD Global Rank",
b."YTD Global Total Points"
from(
select 
a."MONTH",
a."FUSION_ID",
a."UCID",
a."NAME" "SUPV_NAME",
a."TEAM_LEADER" "MANAGER_NAME",
a."LOCATION",
a."DEPT",
round((coalesce( a."Res Credit Points",0)+ coalesce(a."Stella Star Points",0)+ coalesce(a."Adherence Points",0)+
coalesce(a."AHT Points",0)+coalesce(a."CMS Usage Points",0)+ coalesce(a."TL Call Monitoring Points",0)
+coalesce(a."Collection call Model Points",0)),2)  "Overall Score",
rank() OVER (PARTITION by month ORDER BY round((coalesce( a."Res Credit Points",0)+ coalesce(a."Stella Star Points",0)+ coalesce(a."Adherence Points",0)+
coalesce(a."AHT Points",0)+coalesce(a."CMS Usage Points",0)+ coalesce(a."TL Call Monitoring Points",0)
+coalesce(a."Collection call Model Points",0)),2) desc,month ) "Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Defect Rank",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Defect Rank",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from (
select 
--"EMPLOYEE ID"--,name,"Team Lead",location,dept
b.month,b.TL_FUSIONID "FUSION_ID",
c.ucid
,b."Team Lead" NAME, c.team_leader,c.location,c.dept
,round(avg(b."Credit Per Hr"),3) "Resolution Credits"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept ) "Res Credit Rank"
,case when round(avg(b."Credit Per Hr"),3) >2.000 then 
(case when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.15,0) then 11.25 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.6,0) then 7.5 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.85,0) then 3.75 
else 0 end )
else 0
end as "Res Credit Points"
,i.cph_target
--,round(avg(b."Quality Score"),2) "Quality Score"
--,i.QUALITY_TARGET
,round(avg(b."Stella Star Rating"),2) "Stella Star Rating"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Stella Star Rating"),2) desc,b.month,c.dept ) "Stella Star Rank"
, case when round(avg(b."Stella Star Rating"),2) >4.6 then  5-(5*0.20)
when round(avg(b."Stella Star Rating"),2) >=4.5 then  5-(5*0.40)
when round(avg(b."Stella Star Rating"),2) >=4.4 then  5-(5*0.60)
when round(avg(b."Stella Star Rating"),2) >=4.3 then  5-(5*0.80)
else 0 
end as "Stella Star Points"
,i.STAR_TARGET
,round(avg(b."Schedule Adherence"),2) "Schedule Adherence"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Schedule Adherence"),2) desc,b.month,c.dept ) "Adherence Rank"
, case when round(avg(b."Schedule Adherence"),3)>92.50 then 5-(5*0.20)
when round(avg(b."Schedule Adherence"),3)>=90.00 then 5-(5*0.40)
when round(avg(b."Schedule Adherence"),3)>=87.50 then 5-(5*0.60)
when round(avg(b."Schedule Adherence"),3)>=85.00 then 5-(5*0.80)
else 0 end as "Adherence Points"
,i.ADHERENCE_TARGET
,round(avg(b."Inbound AHT"),2) "Inbound AHT"
--,coalesce (j."Inbound AHT",0) "Inbound AHT"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Inbound AHT"),2) desc,b.month,c.dept ) "AHT Rank"
,case when round(avg(b."Inbound AHT"),2)>660 then 0
 when round(avg(b."Inbound AHT"),2) >=660 then 5-(5*0.80)
when round(avg(b."Inbound AHT"),2) >=630 then 5-(5*0.60)
when round(avg(b."Inbound AHT"),2) >=600 then 5-(5*0.40)
else 5-(5*0.20) end as "AHT Points"
,i.ib_aht_target
,round(avg(b."Cms Defect %"),2) "Cms Defect %"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Cms Defect %"),2) asc,b.month,c.dept ) "Cms Defect Rank"
,case when round(avg(b."Cms Defect %"),2) <0.5 then 18.75
when round(avg(b."Cms Defect %"),2) < 1.0 then 12.5
when round(avg(b."Cms Defect %"),2) <1.5 then 6.25
else 0
end as "CMS Usage Points"
,i.CMS_DEFECT_TARGET
,f.qc_per "TL Call Monitoring Defect"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY f.qc_per desc,b.month,c.dept ) "TL Call Monitoring Defect Rank"
,case when f.qc_per = 0 then  7.5
when f.qc_per <= 25 then  5
when f.qc_per <= 75 then  2.5
else 0
end as  "TL Call Monitoring Points"
,i.call_monitoring_defect_target
,e.defect_per "Collection call Model Defect"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY e.defect_per desc,b.month,c.dept ) "Collection call Model Defect Rank"
,case when e.defect_per < 1.5 then 7.5
when e.defect_per < 2.5 then 5
when e.defect_per < 3.5 then 2.5
else 0
end as "Collection call Model Points"
,i.collection_call_model_defect_target
,k."Out Of"
from
(
select 
a.month  ,a.ucid,a."EMPLOYEE ID",a.name,a.TL_FUSIONID,a."Team Lead",a.location,a.dept
,rank() OVER (PARTITION by a.month,a.dept ORDER BY
(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") desc,a.dept,a.month ) "Global Rank"
,(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") "Total Points"
,coalesce(a."Credit Per Hr",0) "Credit Per Hr" ,a."Credit Rank",a."Credits Score",a.CPH_TARGET
, coalesce (a."Quality Score",0)  "Quality Score"
,case when a."Quality Rank" is null then 1 else a."Quality Rank" end as "Quality Rank"
,coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0) as "Quality_Score",a.QUALITY_TARGET
,coalesce(a."Stella Star Rating",0) "Stella Star Rating"
,case when a."Stella Star Rank" is null then 1 else a."Stella Star Rank" end as "Stella Star Rank"
,coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0) as "Stella Star Score",a.STAR_TARGET
,coalesce(a."Schedule Adherence",0) "Schedule Adherence",a."Adherence Rank",a."Adherence Score",a.ADHERENCE_TARGET
,coalesce(a."Inbound AHT",0) "Inbound AHT",a."AHT Rank",a."AHT Score",a.IB_AHT_TARGET
,coalesce(a."Cms Defect %",0) "Cms Defect %" ,a."Cms Defect Rank",a."Cms Defect Score",a.CMS_DEFECT_TARGET
,a."Out Of"
from
(
select 
last_day(a.month) month,
a.ucid,
a.fusionid "EMPLOYEE ID",
a.name,
a.TL_FUSIONID,
a.team_leader "Team Lead",
a.location,
a.dept
--,rank() OVER (PARTITION by last_day(a.month),a.dept ORDER BY (coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0)) desc,a.dept,last_day(a.month) ) "Global Rank"
--,(coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0))  "Total Points"
,b."Credit Per Hr",b."Credit Rank",b."Credits Score",
--b.CPH_TARGET
i.CPH_TARGET
,c."Quality Score",c."Quality Rank",c."Quality_Score"
,i.QUALITY_TARGET
,d."Stella Star Rating",d."Stella Star Rank",d."Stella Star Score"
,i.STAR_TARGET
,e."Schedule Adherence",e."Adherence Rank",e."Adherence Score"
,i.ADHERENCE_TARGET
,f."Inbound AHT",f."AHT Rank",f."AHT Score"
,i.IB_AHT_TARGET
,g."Cms Defect %",g."Cms Defect Rank",g."Cms Defect Score"
,i.CMS_DEFECT_TARGET
,h."Out Of"
from asit_roster_table a
left join(
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
--,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
,"CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
,e."CPH_TARGET"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
left join(
select month,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95","CPH_TARGET"
from (
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of"
)a )b
where "CPH_TARGET" is not null)e on last_day(a.rpt_month)=last_day(e.month) and c.dept=e.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of",e."CPH_TARGET"
)a
) b on last_day(a.month)=last_day(b.month) and a.fusionid=b.fusionid
left join(
select last_day(roster_month) month,
a.fusion_id,c.ucid,a.employee_name,c.dept
,coalesce(round(avg(score),2),0) "Quality Score"
,rank() OVER (PARTITION by last_day(roster_month),c.dept ORDER BY coalesce(round(avg(score),2),0) desc,c.dept,last_day(roster_month) )  "Quality Rank"
,b."Out Of"
,case 
when coalesce(round(avg(score),2),0) >=97.50  then 3.75 
when coalesce(round(avg(score),2),0) >=95.20  then 2.5
when coalesce(round(avg(score),2),0) >=90  then 1.25 
else 0
end as
"Quality_Score"
from asit_quality a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.roster_month)=c.month and a.fusion_id=c.fusionid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.roster_month)=b.monthn and b.dept=c.dept
--where a.roster_month=last_day('31-JAN-24') 
--and a.ucid in (select distinct ucid from asit_roster_table where fusionid='105554' ) 
group by last_day(roster_month),a.fusion_id,c.ucid,a.employee_name,c.dept,b."Out Of"

)c on last_day(a.month)=last_day(c.month) and a.fusionid=c.fusion_id
left join(
select 
last_day(a.month) month,a.employee_custom_id,c.dept
--,a.team_leader
,coalesce(round(avg(star_rating),2),0) "Stella Star Rating"
,rank() OVER (PARTITION by last_day(a.month),c.dept  ORDER BY coalesce(round(avg(star_rating),2),0) desc,c.dept ,last_day(a.month) ) "Stella Star Rank"
,b."Out Of"
,case when coalesce(round(avg(star_rating),2),0) >= 4.6 then 4.00
when coalesce(round(avg(star_rating),2),0) >= 4.5 then 3.00 
when coalesce(round(avg(star_rating),2),0) >= 4.4 then 2.00
when coalesce(round(avg(star_rating),2),0) >= 4.3 then 1.00
else 0
end as "Stella Star Score"
from asit_star_rating a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.employee_custom_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
--where  a.month=last_day(a.month)
--and employee_custom_id in ('196400') 
group by last_day(a.month),c.dept,a.employee_custom_id,b."Out Of"
)d on last_day(a.month)=last_day(d.month) and a.fusionid=d.employee_custom_id
left join (
select 
last_day(a.month) month,a.fusion_id,c.dept 
,coalesce(round(adherence_percentage*100,2),0) "Schedule Adherence"
,rank() OVER (PARTITION by last_day(a.month),c.dept ORDER BY coalesce(round(adherence_percentage*100,2),0) desc,c.dept ,last_day(a.month) ) "Adherence Rank"
,b."Out Of"
,case when coalesce(round(adherence_percentage*100,2),0) >=95 then 4.00 
when coalesce(round(adherence_percentage*100,2),0) >=92.5 then 3.00
when coalesce(round(adherence_percentage*100,2),0) >=90 then 2.00 
when coalesce(round(adherence_percentage*100,2),0) >=87.5 then 1.00
else 0
end as
"Adherence Score"
from asit_telephony a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.fusion_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)e on last_day(a.month)=last_day(e.month) and a.fusionid=e.fusion_id
left join (
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
)f on to_char(last_day(a.month),'MON-YY')=f.month and a.fusionid=f.fusionid
left join(
select 
last_day(a.month) month,c.fusionid,a.ucid,c.dept,a.cms_defect_percentage,coalesce(round(a.cms_defect_percentage*100,2),0) "Cms Defect %"
,rank() OVER (PARTITION by a.month ORDER BY coalesce(round(a.cms_defect_percentage*100,2),0) asc,a.month ) "Cms Defect Rank"
,b."Out Of"
,case when coalesce(round(a.cms_defect_percentage*100,2),0) <0.5 then 18.5 
when coalesce(round(a.cms_defect_percentage*100,2),0) <1 then 12.5
when coalesce(round(a.cms_defect_percentage*100,2),0) <=1.5 then 6.25
else 0
end as
"Cms Defect Score"
from asit_cms_defect a
join(
select month,fusionid,ucid,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.ucid=c.ucid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)g on last_day(a.month)=g.month and a.fusionid=g.fusionid
left join(
select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)h on last_day(a.month)=h.monthn and a.dept=h.dept
left join CR_SC_AGNTS_TARGET i on last_day(a.month)=i.month and a.dept=i.dept
where --a.month>=last_day(sysdate)and
 a.dept in ('CCC-R','CCC-R SPANISH','FLEX')
and a.location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and a.designation in ('Agent')
and a.final_status='ACTIVE'
and a.team_leader not in (select name from not_teamleader)
)a)b
join(
select month,fusionid,ucid,name,TL_FUSIONID,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on b.month=c.month and b.TL_FUSIONID=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)d on b.month=d.monthn and c.dept=d.dept
left join (
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end defect_per 
 from asit_tl_impact
)e on b.month=e.month and b.TL_FUSIONID=e.fusionid
left join(
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end QC_per 
 from asit_tl_qc
)f on b.month=f.month and b.TL_FUSIONID=f.fusionid
left join CR_SC_TL_TARGET i on b.month=i.month and c.dept=i.dept
left join(
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept

) j on to_char(b.month,'MON-YY')=j.month and b.TL_FUSIONID=j.fusionid
left join (select 
to_char(last_day(month),'MON-YY') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-YY'),dept
)k on to_char(b.month,'MON-YY')=k.monthn and c.dept=k.dept
--where  "EMPLOYEE ID" in('197233')
group by b.month,b.TL_FUSIONID,b."Team Lead"
,c.fusionid,c.ucid, c.team_leader,c.location,c.dept,
i.cph_target,i.STAR_TARGET,i.ADHERENCE_TARGET,i.CMS_DEFECT_TARGET,i.collection_call_model_defect_target,i.call_monitoring_defect_target,i.ib_aht_target
,e.defect_per,f.QC_per,j."Inbound AHT",k."Out Of"
)a )a
left join (
select 
fusion_id,
 "YTD Global Rank",
"YTD Global Total Points"
from (
select 
a.fusion_id
,rank() OVER (order by sum(a."Overall Score") desc)  "YTD Global Rank"
,sum(a."Overall Score") "YTD Global Total Points"
from(
select 
to_char(a."MONTH",'MON-YY') "MONTH",
a."FUSION_ID",
a."UCID",
a."SUPV_NAME",
a."MANAGER_NAME",
a."LOCATION",
a."DEPT",
a."Overall Score",
a."Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from(
select 
a."MONTH",
a."FUSION_ID",
a."UCID",
a."NAME" "SUPV_NAME",
a."TEAM_LEADER" "MANAGER_NAME",
a."LOCATION",
a."DEPT",
round((a."Res Credit Points"+a."Stella Star Points"+a."Adherence Points"+a."AHT Points"+a."CMS Usage Points"
+a."TL Call Monitoring Points"+a."Collection call Model Points"),2)  "Overall Score",
rank() OVER (PARTITION by month ORDER BY round((a."Res Credit Points"+a."Stella Star Points"+a."Adherence Points"+a."AHT Points"+a."CMS Usage Points"
+a."TL Call Monitoring Points"+a."Collection call Model Points"),2) desc,month ) "Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from (
select 
--"EMPLOYEE ID"--,name,"Team Lead",location,dept
b.month,b.TL_FUSIONID "FUSION_ID",
c.ucid
,b."Team Lead" NAME, c.team_leader,c.location,c.dept
,round(avg(b."Credit Per Hr"),3) "Resolution Credits"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept ) "Res Credit Rank"
,case when round(avg(b."Credit Per Hr"),3) >2.000 then 
(case when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.15,0) then 11.25 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.6,0) then 7.5 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.85,0) then 3.75 
else 0 end )
else 0
end as "Res Credit Points"
,i.cph_target
--,round(avg(b."Quality Score"),2) "Quality Score"
--,i.QUALITY_TARGET
,round(avg(b."Stella Star Rating"),2) "Stella Star Rating"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Stella Star Rating"),2) desc,b.month,c.dept ) "Stella Star Rank"
, case when round(avg(b."Stella Star Rating"),2) >4.6 then  5-(5*0.20)
when round(avg(b."Stella Star Rating"),2) >=4.5 then  5-(5*0.40)
when round(avg(b."Stella Star Rating"),2) >=4.4 then  5-(5*0.60)
when round(avg(b."Stella Star Rating"),2) >=4.3 then  5-(5*0.80)
else 0 
end as "Stella Star Points"
,i.STAR_TARGET
,round(avg(b."Schedule Adherence"),2) "Schedule Adherence"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Schedule Adherence"),2) desc,b.month,c.dept ) "Adherence Rank"
, case when round(avg(b."Schedule Adherence"),3)>92.50 then 5-(5*0.20)
when round(avg(b."Schedule Adherence"),3)>=90.00 then 5-(5*0.40)
when round(avg(b."Schedule Adherence"),3)>=87.50 then 5-(5*0.60)
when round(avg(b."Schedule Adherence"),3)>=85.00 then 5-(5*0.80)
else 0 end as "Adherence Points"
,i.ADHERENCE_TARGET
,round(avg(b."Inbound AHT"),2) "Inbound AHT"
--,coalesce (j."Inbound AHT",0) "Inbound AHT"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Inbound AHT"),2) desc,b.month,c.dept ) "AHT Rank"
,case when round(avg(b."Inbound AHT"),2)>660 then 0
 when round(avg(b."Inbound AHT"),2) >=660 then 5-(5*0.80)
when round(avg(b."Inbound AHT"),2) >=630 then 5-(5*0.60)
when round(avg(b."Inbound AHT"),2) >=600 then 5-(5*0.40)
else 5-(5*0.20) end as "AHT Points"
,i.ib_aht_target
,round(avg(b."Cms Defect %"),2) "Cms Defect %"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Cms Defect %"),2) asc,b.month,c.dept ) "Cms Defect Rank"
,case when round(avg(b."Cms Defect %"),2) <0.5 then 18.75
when round(avg(b."Cms Defect %"),2) < 1.0 then 12.5
when round(avg(b."Cms Defect %"),2) <1.5 then 6.25
else 0
end as "CMS Usage Points"
,i.CMS_DEFECT_TARGET
,f.qc_per "TL Call Monitoring Defect"
,case when f.qc_per = 0 then  7.5
when f.qc_per <= 25 then  5
when f.qc_per <= 75 then  2.5
else 0
end as  "TL Call Monitoring Points"
,i.call_monitoring_defect_target
,e.defect_per "Collection call Model Defect"
,case when e.defect_per < 1.5 then 7.5
when e.defect_per < 2.5 then 5
when e.defect_per < 3.5 then 2.5
else 0
end as "Collection call Model Points"
,i.collection_call_model_defect_target
,k."Out Of"
from
(
select 
a.month  ,a.ucid,a."EMPLOYEE ID",a.name,a.TL_FUSIONID,a."Team Lead",a.location,a.dept
,rank() OVER (PARTITION by a.month,a.dept ORDER BY
(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") desc,a.dept,a.month ) "Global Rank"
,(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") "Total Points"
,coalesce(a."Credit Per Hr",0) "Credit Per Hr" ,a."Credit Rank",a."Credits Score",a.CPH_TARGET
, coalesce (a."Quality Score",0)  "Quality Score"
,case when a."Quality Rank" is null then 1 else a."Quality Rank" end as "Quality Rank"
,coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0) as "Quality_Score",a.QUALITY_TARGET
,coalesce(a."Stella Star Rating",0) "Stella Star Rating"
,case when a."Stella Star Rank" is null then 1 else a."Stella Star Rank" end as "Stella Star Rank"
,coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0) as "Stella Star Score",a.STAR_TARGET
,coalesce(a."Schedule Adherence",0) "Schedule Adherence",a."Adherence Rank",a."Adherence Score",a.ADHERENCE_TARGET
,coalesce(a."Inbound AHT",0) "Inbound AHT",a."AHT Rank",a."AHT Score",a.IB_AHT_TARGET
,coalesce(a."Cms Defect %",0) "Cms Defect %" ,a."Cms Defect Rank",a."Cms Defect Score",a.CMS_DEFECT_TARGET
,a."Out Of"
from
(
select 
last_day(a.month) month,
a.ucid,
a.fusionid "EMPLOYEE ID",
a.name,
a.TL_FUSIONID,
a.team_leader "Team Lead",
a.location,
a.dept
--,rank() OVER (PARTITION by last_day(a.month),a.dept ORDER BY (coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0)) desc,a.dept,last_day(a.month) ) "Global Rank"
--,(coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0))  "Total Points"
,b."Credit Per Hr",b."Credit Rank",b."Credits Score",
--b.CPH_TARGET
i.CPH_TARGET
,c."Quality Score",c."Quality Rank",c."Quality_Score"
,i.QUALITY_TARGET
,d."Stella Star Rating",d."Stella Star Rank",d."Stella Star Score"
,i.STAR_TARGET
,e."Schedule Adherence",e."Adherence Rank",e."Adherence Score"
,i.ADHERENCE_TARGET
,f."Inbound AHT",f."AHT Rank",f."AHT Score"
,i.IB_AHT_TARGET
,g."Cms Defect %",g."Cms Defect Rank",g."Cms Defect Score"
,i.CMS_DEFECT_TARGET
,h."Out Of"
from asit_roster_table a
left join(
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
--,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
,"CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
,e."CPH_TARGET"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
left join(
select month,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95","CPH_TARGET"
from (
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of"
)a )b
where "CPH_TARGET" is not null)e on last_day(a.rpt_month)=last_day(e.month) and c.dept=e.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of",e."CPH_TARGET"
)a
) b on last_day(a.month)=last_day(b.month) and a.fusionid=b.fusionid
left join(
select last_day(roster_month) month,
a.fusion_id,c.ucid,a.employee_name,c.dept
,coalesce(round(avg(score),2),0) "Quality Score"
,rank() OVER (PARTITION by last_day(roster_month),c.dept ORDER BY coalesce(round(avg(score),2),0) desc,c.dept,last_day(roster_month) )  "Quality Rank"
,b."Out Of"
,case 
when coalesce(round(avg(score),2),0) >=97.50  then 3.75 
when coalesce(round(avg(score),2),0) >=95.20  then 2.5
when coalesce(round(avg(score),2),0) >=90  then 1.25 
else 0
end as
"Quality_Score"
from asit_quality a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.roster_month)=c.month and a.fusion_id=c.fusionid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.roster_month)=b.monthn and b.dept=c.dept
--where a.roster_month=last_day('31-JAN-24') 
--and a.ucid in (select distinct ucid from asit_roster_table where fusionid='105554' ) 
group by last_day(roster_month),a.fusion_id,c.ucid,a.employee_name,c.dept,b."Out Of"

)c on last_day(a.month)=last_day(c.month) and a.fusionid=c.fusion_id
left join(
select 
last_day(a.month) month,a.employee_custom_id,c.dept
--,a.team_leader
,coalesce(round(avg(star_rating),2),0) "Stella Star Rating"
,rank() OVER (PARTITION by last_day(a.month),c.dept  ORDER BY coalesce(round(avg(star_rating),2),0) desc,c.dept ,last_day(a.month) ) "Stella Star Rank"
,b."Out Of"
,case when coalesce(round(avg(star_rating),2),0) >= 4.6 then 4.00
when coalesce(round(avg(star_rating),2),0) >= 4.5 then 3.00 
when coalesce(round(avg(star_rating),2),0) >= 4.4 then 2.00
when coalesce(round(avg(star_rating),2),0) >= 4.3 then 1.00
else 0
end as "Stella Star Score"
from asit_star_rating a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.employee_custom_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
--where  a.month=last_day(a.month)
--and employee_custom_id in ('196400') 
group by last_day(a.month),c.dept,a.employee_custom_id,b."Out Of"
)d on last_day(a.month)=last_day(d.month) and a.fusionid=d.employee_custom_id
left join (
select 
last_day(a.month) month,a.fusion_id,c.dept 
,coalesce(round(adherence_percentage*100,2),0) "Schedule Adherence"
,rank() OVER (PARTITION by last_day(a.month),c.dept ORDER BY coalesce(round(adherence_percentage*100,2),0) desc,c.dept ,last_day(a.month) ) "Adherence Rank"
,b."Out Of"
,case when coalesce(round(adherence_percentage*100,2),0) >=95 then 4.00 
when coalesce(round(adherence_percentage*100,2),0) >=92.5 then 3.00
when coalesce(round(adherence_percentage*100,2),0) >=90 then 2.00 
when coalesce(round(adherence_percentage*100,2),0) >=87.5 then 1.00
else 0
end as
"Adherence Score"
from asit_telephony a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.fusion_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)e on last_day(a.month)=last_day(e.month) and a.fusionid=e.fusion_id
left join (
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
)f on to_char(last_day(a.month),'MON-YY')=f.month and a.fusionid=f.fusionid
left join(
select 
last_day(a.month) month,c.fusionid,a.ucid,c.dept,a.cms_defect_percentage,coalesce(round(a.cms_defect_percentage*100,2),0) "Cms Defect %"
,rank() OVER (PARTITION by a.month ORDER BY coalesce(round(a.cms_defect_percentage*100,2),0) asc,a.month ) "Cms Defect Rank"
,b."Out Of"
,case when coalesce(round(a.cms_defect_percentage*100,2),0) <0.5 then 18.5 
when coalesce(round(a.cms_defect_percentage*100,2),0) <1 then 12.5
when coalesce(round(a.cms_defect_percentage*100,2),0) <=1.5 then 6.25
else 0
end as
"Cms Defect Score"
from asit_cms_defect a
join(
select month,fusionid,ucid,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.ucid=c.ucid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)g on last_day(a.month)=g.month and a.fusionid=g.fusionid
left join(
select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)h on last_day(a.month)=h.monthn and a.dept=h.dept
left join CR_SC_AGNTS_TARGET i on last_day(a.month)=i.month and a.dept=i.dept
where --a.month>=last_day(sysdate)and
 a.dept in ('CCC-R','CCC-R SPANISH','FLEX')
and a.location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and a.designation in ('Agent')
and a.final_status='ACTIVE'
and a.team_leader not in (select name from not_teamleader)
)a)b
join(
select month,fusionid,ucid,name,TL_FUSIONID,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on b.month=c.month and b.TL_FUSIONID=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)d on b.month=d.monthn and c.dept=d.dept
left join (
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end defect_per 
 from asit_tl_impact
)e on b.month=e.month and b.TL_FUSIONID=e.fusionid
left join(
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end QC_per 
 from asit_tl_qc
)f on b.month=f.month and b.TL_FUSIONID=f.fusionid
left join CR_SC_TL_TARGET i on b.month=i.month and c.dept=i.dept
left join(
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept

) j on to_char(b.month,'MON-YY')=j.month and b.TL_FUSIONID=j.fusionid
left join (select 
to_char(last_day(month),'MON-YY') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-YY'),dept
)k on to_char(b.month,'MON-YY')=k.monthn and c.dept=k.dept
--where  "EMPLOYEE ID" in('197233')
group by b.month,b.TL_FUSIONID,b."Team Lead"
,c.fusionid,c.ucid, c.team_leader,c.location,c.dept,
i.cph_target,i.STAR_TARGET,i.ADHERENCE_TARGET,i.CMS_DEFECT_TARGET,i.collection_call_model_defect_target,i.call_monitoring_defect_target,i.ib_aht_target
,e.defect_per,f.QC_per,j."Inbound AHT",k."Out Of"
)a )a)a
--where month>=last_day('01-JAN_24')
--where a."FUSION_ID" in ('195869')
group by a.fusion_id
)a 
) b on a.FUSION_ID=b.FUSION_ID
--where month>=last_day('01-JAN_24')
where a."FUSION_ID" in (vfusionid3)
order by a.month asc;

            else
            OPEN p_result FOR 
            
select 
to_char(a."MONTH",'MON-YY') "MONTH",
a."UCID",
a."FUSION_ID" ,
a."SUPV_NAME" "TL NAME" ,
a."MANAGER_NAME" "ASM",
a."LOCATION",
a."DEPT",
a."Overall Rank" "Global Rank",
a."Overall Score" "Total Points",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Defect Rank",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Defect Rank",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of",
b."YTD Global Rank",
b."YTD Global Total Points"
from(
select 
a."MONTH",
a."FUSION_ID",
a."UCID",
a."NAME" "SUPV_NAME",
a."TEAM_LEADER" "MANAGER_NAME",
a."LOCATION",
a."DEPT",
round((coalesce( a."Res Credit Points",0)+ coalesce(a."Stella Star Points",0)+ coalesce(a."Adherence Points",0)+
coalesce(a."AHT Points",0)+coalesce(a."CMS Usage Points",0)+ coalesce(a."TL Call Monitoring Points",0)
+coalesce(a."Collection call Model Points",0)),2)  "Overall Score",
rank() OVER (PARTITION by month ORDER BY round((coalesce( a."Res Credit Points",0)+ coalesce(a."Stella Star Points",0)+ coalesce(a."Adherence Points",0)+
coalesce(a."AHT Points",0)+coalesce(a."CMS Usage Points",0)+ coalesce(a."TL Call Monitoring Points",0)
+coalesce(a."Collection call Model Points",0)),2) desc,month ) "Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Defect Rank",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Defect Rank",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from (
select 
--"EMPLOYEE ID"--,name,"Team Lead",location,dept
b.month,b.TL_FUSIONID "FUSION_ID",
c.ucid
,b."Team Lead" NAME, c.team_leader,c.location,c.dept
,round(avg(b."Credit Per Hr"),3) "Resolution Credits"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept ) "Res Credit Rank"
,case when round(avg(b."Credit Per Hr"),3) >2.000 then 
(case when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.15,0) then 11.25 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.6,0) then 7.5 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.85,0) then 3.75 
else 0 end )
else 0
end as "Res Credit Points"
,i.cph_target
--,round(avg(b."Quality Score"),2) "Quality Score"
--,i.QUALITY_TARGET
,round(avg(b."Stella Star Rating"),2) "Stella Star Rating"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Stella Star Rating"),2) desc,b.month,c.dept ) "Stella Star Rank"
, case when round(avg(b."Stella Star Rating"),2) >4.6 then  5-(5*0.20)
when round(avg(b."Stella Star Rating"),2) >=4.5 then  5-(5*0.40)
when round(avg(b."Stella Star Rating"),2) >=4.4 then  5-(5*0.60)
when round(avg(b."Stella Star Rating"),2) >=4.3 then  5-(5*0.80)
else 0 
end as "Stella Star Points"
,i.STAR_TARGET
,round(avg(b."Schedule Adherence"),2) "Schedule Adherence"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Schedule Adherence"),2) desc,b.month,c.dept ) "Adherence Rank"
, case when round(avg(b."Schedule Adherence"),3)>92.50 then 5-(5*0.20)
when round(avg(b."Schedule Adherence"),3)>=90.00 then 5-(5*0.40)
when round(avg(b."Schedule Adherence"),3)>=87.50 then 5-(5*0.60)
when round(avg(b."Schedule Adherence"),3)>=85.00 then 5-(5*0.80)
else 0 end as "Adherence Points"
,i.ADHERENCE_TARGET
,round(avg(b."Inbound AHT"),2) "Inbound AHT"
--,coalesce (j."Inbound AHT",0) "Inbound AHT"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Inbound AHT"),2) desc,b.month,c.dept ) "AHT Rank"
,case when round(avg(b."Inbound AHT"),2)>660 then 0
 when round(avg(b."Inbound AHT"),2) >=660 then 5-(5*0.80)
when round(avg(b."Inbound AHT"),2) >=630 then 5-(5*0.60)
when round(avg(b."Inbound AHT"),2) >=600 then 5-(5*0.40)
else 5-(5*0.20) end as "AHT Points"
,i.ib_aht_target
,round(avg(b."Cms Defect %"),2) "Cms Defect %"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Cms Defect %"),2) asc,b.month,c.dept ) "Cms Defect Rank"
,case when round(avg(b."Cms Defect %"),2) <0.5 then 18.75
when round(avg(b."Cms Defect %"),2) < 1.0 then 12.5
when round(avg(b."Cms Defect %"),2) <1.5 then 6.25
else 0
end as "CMS Usage Points"
,i.CMS_DEFECT_TARGET
,f.qc_per "TL Call Monitoring Defect"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY f.qc_per desc,b.month,c.dept ) "TL Call Monitoring Defect Rank"
,case when f.qc_per = 0 then  7.5
when f.qc_per <= 25 then  5
when f.qc_per <= 75 then  2.5
else 0
end as  "TL Call Monitoring Points"
,i.call_monitoring_defect_target
,e.defect_per "Collection call Model Defect"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY e.defect_per desc,b.month,c.dept ) "Collection call Model Defect Rank"
,case when e.defect_per < 1.5 then 7.5
when e.defect_per < 2.5 then 5
when e.defect_per < 3.5 then 2.5
else 0
end as "Collection call Model Points"
,i.collection_call_model_defect_target
,k."Out Of"
from
(
select 
a.month  ,a.ucid,a."EMPLOYEE ID",a.name,a.TL_FUSIONID,a."Team Lead",a.location,a.dept
,rank() OVER (PARTITION by a.month,a.dept ORDER BY
(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") desc,a.dept,a.month ) "Global Rank"
,(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") "Total Points"
,coalesce(a."Credit Per Hr",0) "Credit Per Hr" ,a."Credit Rank",a."Credits Score",a.CPH_TARGET
, coalesce (a."Quality Score",0)  "Quality Score"
,case when a."Quality Rank" is null then 1 else a."Quality Rank" end as "Quality Rank"
,coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0) as "Quality_Score",a.QUALITY_TARGET
,coalesce(a."Stella Star Rating",0) "Stella Star Rating"
,case when a."Stella Star Rank" is null then 1 else a."Stella Star Rank" end as "Stella Star Rank"
,coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0) as "Stella Star Score",a.STAR_TARGET
,coalesce(a."Schedule Adherence",0) "Schedule Adherence",a."Adherence Rank",a."Adherence Score",a.ADHERENCE_TARGET
,coalesce(a."Inbound AHT",0) "Inbound AHT",a."AHT Rank",a."AHT Score",a.IB_AHT_TARGET
,coalesce(a."Cms Defect %",0) "Cms Defect %" ,a."Cms Defect Rank",a."Cms Defect Score",a.CMS_DEFECT_TARGET
,a."Out Of"
from
(
select 
last_day(a.month) month,
a.ucid,
a.fusionid "EMPLOYEE ID",
a.name,
a.TL_FUSIONID,
a.team_leader "Team Lead",
a.location,
a.dept
--,rank() OVER (PARTITION by last_day(a.month),a.dept ORDER BY (coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0)) desc,a.dept,last_day(a.month) ) "Global Rank"
--,(coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0))  "Total Points"
,b."Credit Per Hr",b."Credit Rank",b."Credits Score",
--b.CPH_TARGET
i.CPH_TARGET
,c."Quality Score",c."Quality Rank",c."Quality_Score"
,i.QUALITY_TARGET
,d."Stella Star Rating",d."Stella Star Rank",d."Stella Star Score"
,i.STAR_TARGET
,e."Schedule Adherence",e."Adherence Rank",e."Adherence Score"
,i.ADHERENCE_TARGET
,f."Inbound AHT",f."AHT Rank",f."AHT Score"
,i.IB_AHT_TARGET
,g."Cms Defect %",g."Cms Defect Rank",g."Cms Defect Score"
,i.CMS_DEFECT_TARGET
,h."Out Of"
from asit_roster_table a
left join(
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
--,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
,"CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
,e."CPH_TARGET"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
left join(
select month,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95","CPH_TARGET"
from (
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of"
)a )b
where "CPH_TARGET" is not null)e on last_day(a.rpt_month)=last_day(e.month) and c.dept=e.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of",e."CPH_TARGET"
)a
) b on last_day(a.month)=last_day(b.month) and a.fusionid=b.fusionid
left join(
select last_day(roster_month) month,
a.fusion_id,c.ucid,a.employee_name,c.dept
,coalesce(round(avg(score),2),0) "Quality Score"
,rank() OVER (PARTITION by last_day(roster_month),c.dept ORDER BY coalesce(round(avg(score),2),0) desc,c.dept,last_day(roster_month) )  "Quality Rank"
,b."Out Of"
,case 
when coalesce(round(avg(score),2),0) >=97.50  then 3.75 
when coalesce(round(avg(score),2),0) >=95.20  then 2.5
when coalesce(round(avg(score),2),0) >=90  then 1.25 
else 0
end as
"Quality_Score"
from asit_quality a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.roster_month)=c.month and a.fusion_id=c.fusionid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.roster_month)=b.monthn and b.dept=c.dept
--where a.roster_month=last_day('31-JAN-24') 
--and a.ucid in (select distinct ucid from asit_roster_table where fusionid='105554' ) 
group by last_day(roster_month),a.fusion_id,c.ucid,a.employee_name,c.dept,b."Out Of"

)c on last_day(a.month)=last_day(c.month) and a.fusionid=c.fusion_id
left join(
select 
last_day(a.month) month,a.employee_custom_id,c.dept
--,a.team_leader
,coalesce(round(avg(star_rating),2),0) "Stella Star Rating"
,rank() OVER (PARTITION by last_day(a.month),c.dept  ORDER BY coalesce(round(avg(star_rating),2),0) desc,c.dept ,last_day(a.month) ) "Stella Star Rank"
,b."Out Of"
,case when coalesce(round(avg(star_rating),2),0) >= 4.6 then 4.00
when coalesce(round(avg(star_rating),2),0) >= 4.5 then 3.00 
when coalesce(round(avg(star_rating),2),0) >= 4.4 then 2.00
when coalesce(round(avg(star_rating),2),0) >= 4.3 then 1.00
else 0
end as "Stella Star Score"
from asit_star_rating a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.employee_custom_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
--where  a.month=last_day(a.month)
--and employee_custom_id in ('196400') 
group by last_day(a.month),c.dept,a.employee_custom_id,b."Out Of"
)d on last_day(a.month)=last_day(d.month) and a.fusionid=d.employee_custom_id
left join (
select 
last_day(a.month) month,a.fusion_id,c.dept 
,coalesce(round(adherence_percentage*100,2),0) "Schedule Adherence"
,rank() OVER (PARTITION by last_day(a.month),c.dept ORDER BY coalesce(round(adherence_percentage*100,2),0) desc,c.dept ,last_day(a.month) ) "Adherence Rank"
,b."Out Of"
,case when coalesce(round(adherence_percentage*100,2),0) >=95 then 4.00 
when coalesce(round(adherence_percentage*100,2),0) >=92.5 then 3.00
when coalesce(round(adherence_percentage*100,2),0) >=90 then 2.00 
when coalesce(round(adherence_percentage*100,2),0) >=87.5 then 1.00
else 0
end as
"Adherence Score"
from asit_telephony a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.fusion_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)e on last_day(a.month)=last_day(e.month) and a.fusionid=e.fusion_id
left join (
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
)f on to_char(last_day(a.month),'MON-YY')=f.month and a.fusionid=f.fusionid
left join(
select 
last_day(a.month) month,c.fusionid,a.ucid,c.dept,a.cms_defect_percentage,coalesce(round(a.cms_defect_percentage*100,2),0) "Cms Defect %"
,rank() OVER (PARTITION by a.month ORDER BY coalesce(round(a.cms_defect_percentage*100,2),0) asc,a.month ) "Cms Defect Rank"
,b."Out Of"
,case when coalesce(round(a.cms_defect_percentage*100,2),0) <0.5 then 18.5 
when coalesce(round(a.cms_defect_percentage*100,2),0) <1 then 12.5
when coalesce(round(a.cms_defect_percentage*100,2),0) <=1.5 then 6.25
else 0
end as
"Cms Defect Score"
from asit_cms_defect a
join(
select month,fusionid,ucid,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.ucid=c.ucid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)g on last_day(a.month)=g.month and a.fusionid=g.fusionid
left join(
select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)h on last_day(a.month)=h.monthn and a.dept=h.dept
left join CR_SC_AGNTS_TARGET i on last_day(a.month)=i.month and a.dept=i.dept
where --a.month>=last_day(sysdate)and
 a.dept in ('CCC-R','CCC-R SPANISH','FLEX')
and a.location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and a.designation in ('Agent')
and a.final_status='ACTIVE'
and a.team_leader not in (select name from not_teamleader)
)a)b
join(
select month,fusionid,ucid,name,TL_FUSIONID,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on b.month=c.month and b.TL_FUSIONID=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)d on b.month=d.monthn and c.dept=d.dept
left join (
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end defect_per 
 from asit_tl_impact
)e on b.month=e.month and b.TL_FUSIONID=e.fusionid
left join(
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end QC_per 
 from asit_tl_qc
)f on b.month=f.month and b.TL_FUSIONID=f.fusionid
left join CR_SC_TL_TARGET i on b.month=i.month and c.dept=i.dept
left join(
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept

) j on to_char(b.month,'MON-YY')=j.month and b.TL_FUSIONID=j.fusionid
left join (select 
to_char(last_day(month),'MON-YY') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-YY'),dept
)k on to_char(b.month,'MON-YY')=k.monthn and c.dept=k.dept
--where  "EMPLOYEE ID" in('197233')
group by b.month,b.TL_FUSIONID,b."Team Lead"
,c.fusionid,c.ucid, c.team_leader,c.location,c.dept,
i.cph_target,i.STAR_TARGET,i.ADHERENCE_TARGET,i.CMS_DEFECT_TARGET,i.collection_call_model_defect_target,i.call_monitoring_defect_target,i.ib_aht_target
,e.defect_per,f.QC_per,j."Inbound AHT",k."Out Of"
)a )a
left join (
select 
fusion_id,
 "YTD Global Rank",
"YTD Global Total Points"
from (
select 
a.fusion_id
,rank() OVER (order by sum(a."Overall Score") desc)  "YTD Global Rank"
,sum(a."Overall Score") "YTD Global Total Points"
from(
select 
to_char(a."MONTH",'MON-YY') "MONTH",
a."FUSION_ID",
a."UCID",
a."SUPV_NAME",
a."MANAGER_NAME",
a."LOCATION",
a."DEPT",
a."Overall Score",
a."Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from(
select 
a."MONTH",
a."FUSION_ID",
a."UCID",
a."NAME" "SUPV_NAME",
a."TEAM_LEADER" "MANAGER_NAME",
a."LOCATION",
a."DEPT",
round((a."Res Credit Points"+a."Stella Star Points"+a."Adherence Points"+a."AHT Points"+a."CMS Usage Points"
+a."TL Call Monitoring Points"+a."Collection call Model Points"),2)  "Overall Score",
rank() OVER (PARTITION by month ORDER BY round((a."Res Credit Points"+a."Stella Star Points"+a."Adherence Points"+a."AHT Points"+a."CMS Usage Points"
+a."TL Call Monitoring Points"+a."Collection call Model Points"),2) desc,month ) "Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from (
select 
--"EMPLOYEE ID"--,name,"Team Lead",location,dept
b.month,b.TL_FUSIONID "FUSION_ID",
c.ucid
,b."Team Lead" NAME, c.team_leader,c.location,c.dept
,round(avg(b."Credit Per Hr"),3) "Resolution Credits"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept ) "Res Credit Rank"
,case when round(avg(b."Credit Per Hr"),3) >2.000 then 
(case when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.15,0) then 11.25 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.6,0) then 7.5 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.85,0) then 3.75 
else 0 end )
else 0
end as "Res Credit Points"
,i.cph_target
--,round(avg(b."Quality Score"),2) "Quality Score"
--,i.QUALITY_TARGET
,round(avg(b."Stella Star Rating"),2) "Stella Star Rating"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Stella Star Rating"),2) desc,b.month,c.dept ) "Stella Star Rank"
, case when round(avg(b."Stella Star Rating"),2) >4.6 then  5-(5*0.20)
when round(avg(b."Stella Star Rating"),2) >=4.5 then  5-(5*0.40)
when round(avg(b."Stella Star Rating"),2) >=4.4 then  5-(5*0.60)
when round(avg(b."Stella Star Rating"),2) >=4.3 then  5-(5*0.80)
else 0 
end as "Stella Star Points"
,i.STAR_TARGET
,round(avg(b."Schedule Adherence"),2) "Schedule Adherence"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Schedule Adherence"),2) desc,b.month,c.dept ) "Adherence Rank"
, case when round(avg(b."Schedule Adherence"),3)>92.50 then 5-(5*0.20)
when round(avg(b."Schedule Adherence"),3)>=90.00 then 5-(5*0.40)
when round(avg(b."Schedule Adherence"),3)>=87.50 then 5-(5*0.60)
when round(avg(b."Schedule Adherence"),3)>=85.00 then 5-(5*0.80)
else 0 end as "Adherence Points"
,i.ADHERENCE_TARGET
,round(avg(b."Inbound AHT"),2) "Inbound AHT"
--,coalesce (j."Inbound AHT",0) "Inbound AHT"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Inbound AHT"),2) desc,b.month,c.dept ) "AHT Rank"
,case when round(avg(b."Inbound AHT"),2)>660 then 0
 when round(avg(b."Inbound AHT"),2) >=660 then 5-(5*0.80)
when round(avg(b."Inbound AHT"),2) >=630 then 5-(5*0.60)
when round(avg(b."Inbound AHT"),2) >=600 then 5-(5*0.40)
else 5-(5*0.20) end as "AHT Points"
,i.ib_aht_target
,round(avg(b."Cms Defect %"),2) "Cms Defect %"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Cms Defect %"),2) asc,b.month,c.dept ) "Cms Defect Rank"
,case when round(avg(b."Cms Defect %"),2) <0.5 then 18.75
when round(avg(b."Cms Defect %"),2) < 1.0 then 12.5
when round(avg(b."Cms Defect %"),2) <1.5 then 6.25
else 0
end as "CMS Usage Points"
,i.CMS_DEFECT_TARGET
,f.qc_per "TL Call Monitoring Defect"
,case when f.qc_per = 0 then  7.5
when f.qc_per <= 25 then  5
when f.qc_per <= 75 then  2.5
else 0
end as  "TL Call Monitoring Points"
,i.call_monitoring_defect_target
,e.defect_per "Collection call Model Defect"
,case when e.defect_per < 1.5 then 7.5
when e.defect_per < 2.5 then 5
when e.defect_per < 3.5 then 2.5
else 0
end as "Collection call Model Points"
,i.collection_call_model_defect_target
,k."Out Of"
from
(
select 
a.month  ,a.ucid,a."EMPLOYEE ID",a.name,a.TL_FUSIONID,a."Team Lead",a.location,a.dept
,rank() OVER (PARTITION by a.month,a.dept ORDER BY
(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") desc,a.dept,a.month ) "Global Rank"
,(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") "Total Points"
,coalesce(a."Credit Per Hr",0) "Credit Per Hr" ,a."Credit Rank",a."Credits Score",a.CPH_TARGET
, coalesce (a."Quality Score",0)  "Quality Score"
,case when a."Quality Rank" is null then 1 else a."Quality Rank" end as "Quality Rank"
,coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0) as "Quality_Score",a.QUALITY_TARGET
,coalesce(a."Stella Star Rating",0) "Stella Star Rating"
,case when a."Stella Star Rank" is null then 1 else a."Stella Star Rank" end as "Stella Star Rank"
,coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0) as "Stella Star Score",a.STAR_TARGET
,coalesce(a."Schedule Adherence",0) "Schedule Adherence",a."Adherence Rank",a."Adherence Score",a.ADHERENCE_TARGET
,coalesce(a."Inbound AHT",0) "Inbound AHT",a."AHT Rank",a."AHT Score",a.IB_AHT_TARGET
,coalesce(a."Cms Defect %",0) "Cms Defect %" ,a."Cms Defect Rank",a."Cms Defect Score",a.CMS_DEFECT_TARGET
,a."Out Of"
from
(
select 
last_day(a.month) month,
a.ucid,
a.fusionid "EMPLOYEE ID",
a.name,
a.TL_FUSIONID,
a.team_leader "Team Lead",
a.location,
a.dept
--,rank() OVER (PARTITION by last_day(a.month),a.dept ORDER BY (coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0)) desc,a.dept,last_day(a.month) ) "Global Rank"
--,(coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0))  "Total Points"
,b."Credit Per Hr",b."Credit Rank",b."Credits Score",
--b.CPH_TARGET
i.CPH_TARGET
,c."Quality Score",c."Quality Rank",c."Quality_Score"
,i.QUALITY_TARGET
,d."Stella Star Rating",d."Stella Star Rank",d."Stella Star Score"
,i.STAR_TARGET
,e."Schedule Adherence",e."Adherence Rank",e."Adherence Score"
,i.ADHERENCE_TARGET
,f."Inbound AHT",f."AHT Rank",f."AHT Score"
,i.IB_AHT_TARGET
,g."Cms Defect %",g."Cms Defect Rank",g."Cms Defect Score"
,i.CMS_DEFECT_TARGET
,h."Out Of"
from asit_roster_table a
left join(
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
--,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
,"CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
,e."CPH_TARGET"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
left join(
select month,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95","CPH_TARGET"
from (
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of"
)a )b
where "CPH_TARGET" is not null)e on last_day(a.rpt_month)=last_day(e.month) and c.dept=e.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of",e."CPH_TARGET"
)a
) b on last_day(a.month)=last_day(b.month) and a.fusionid=b.fusionid
left join(
select last_day(roster_month) month,
a.fusion_id,c.ucid,a.employee_name,c.dept
,coalesce(round(avg(score),2),0) "Quality Score"
,rank() OVER (PARTITION by last_day(roster_month),c.dept ORDER BY coalesce(round(avg(score),2),0) desc,c.dept,last_day(roster_month) )  "Quality Rank"
,b."Out Of"
,case 
when coalesce(round(avg(score),2),0) >=97.50  then 3.75 
when coalesce(round(avg(score),2),0) >=95.20  then 2.5
when coalesce(round(avg(score),2),0) >=90  then 1.25 
else 0
end as
"Quality_Score"
from asit_quality a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.roster_month)=c.month and a.fusion_id=c.fusionid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.roster_month)=b.monthn and b.dept=c.dept
--where a.roster_month=last_day('31-JAN-24') 
--and a.ucid in (select distinct ucid from asit_roster_table where fusionid='105554' ) 
group by last_day(roster_month),a.fusion_id,c.ucid,a.employee_name,c.dept,b."Out Of"

)c on last_day(a.month)=last_day(c.month) and a.fusionid=c.fusion_id
left join(
select 
last_day(a.month) month,a.employee_custom_id,c.dept
--,a.team_leader
,coalesce(round(avg(star_rating),2),0) "Stella Star Rating"
,rank() OVER (PARTITION by last_day(a.month),c.dept  ORDER BY coalesce(round(avg(star_rating),2),0) desc,c.dept ,last_day(a.month) ) "Stella Star Rank"
,b."Out Of"
,case when coalesce(round(avg(star_rating),2),0) >= 4.6 then 4.00
when coalesce(round(avg(star_rating),2),0) >= 4.5 then 3.00 
when coalesce(round(avg(star_rating),2),0) >= 4.4 then 2.00
when coalesce(round(avg(star_rating),2),0) >= 4.3 then 1.00
else 0
end as "Stella Star Score"
from asit_star_rating a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.employee_custom_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
--where  a.month=last_day(a.month)
--and employee_custom_id in ('196400') 
group by last_day(a.month),c.dept,a.employee_custom_id,b."Out Of"
)d on last_day(a.month)=last_day(d.month) and a.fusionid=d.employee_custom_id
left join (
select 
last_day(a.month) month,a.fusion_id,c.dept 
,coalesce(round(adherence_percentage*100,2),0) "Schedule Adherence"
,rank() OVER (PARTITION by last_day(a.month),c.dept ORDER BY coalesce(round(adherence_percentage*100,2),0) desc,c.dept ,last_day(a.month) ) "Adherence Rank"
,b."Out Of"
,case when coalesce(round(adherence_percentage*100,2),0) >=95 then 4.00 
when coalesce(round(adherence_percentage*100,2),0) >=92.5 then 3.00
when coalesce(round(adherence_percentage*100,2),0) >=90 then 2.00 
when coalesce(round(adherence_percentage*100,2),0) >=87.5 then 1.00
else 0
end as
"Adherence Score"
from asit_telephony a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.fusion_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)e on last_day(a.month)=last_day(e.month) and a.fusionid=e.fusion_id
left join (
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
)f on to_char(last_day(a.month),'MON-YY')=f.month and a.fusionid=f.fusionid
left join(
select 
last_day(a.month) month,c.fusionid,a.ucid,c.dept,a.cms_defect_percentage,coalesce(round(a.cms_defect_percentage*100,2),0) "Cms Defect %"
,rank() OVER (PARTITION by a.month ORDER BY coalesce(round(a.cms_defect_percentage*100,2),0) asc,a.month ) "Cms Defect Rank"
,b."Out Of"
,case when coalesce(round(a.cms_defect_percentage*100,2),0) <0.5 then 18.5 
when coalesce(round(a.cms_defect_percentage*100,2),0) <1 then 12.5
when coalesce(round(a.cms_defect_percentage*100,2),0) <=1.5 then 6.25
else 0
end as
"Cms Defect Score"
from asit_cms_defect a
join(
select month,fusionid,ucid,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.ucid=c.ucid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)g on last_day(a.month)=g.month and a.fusionid=g.fusionid
left join(
select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)h on last_day(a.month)=h.monthn and a.dept=h.dept
left join CR_SC_AGNTS_TARGET i on last_day(a.month)=i.month and a.dept=i.dept
where --a.month>=last_day(sysdate)and
 a.dept in ('CCC-R','CCC-R SPANISH','FLEX')
and a.location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and a.designation in ('Agent')
and a.final_status='ACTIVE'
and a.team_leader not in (select name from not_teamleader)
)a)b
join(
select month,fusionid,ucid,name,TL_FUSIONID,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on b.month=c.month and b.TL_FUSIONID=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)d on b.month=d.monthn and c.dept=d.dept
left join (
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end defect_per 
 from asit_tl_impact
)e on b.month=e.month and b.TL_FUSIONID=e.fusionid
left join(
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end QC_per 
 from asit_tl_qc
)f on b.month=f.month and b.TL_FUSIONID=f.fusionid
left join CR_SC_TL_TARGET i on b.month=i.month and c.dept=i.dept
left join(
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept

) j on to_char(b.month,'MON-YY')=j.month and b.TL_FUSIONID=j.fusionid
left join (select 
to_char(last_day(month),'MON-YY') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-YY'),dept
)k on to_char(b.month,'MON-YY')=k.monthn and c.dept=k.dept
--where  "EMPLOYEE ID" in('197233')
group by b.month,b.TL_FUSIONID,b."Team Lead"
,c.fusionid,c.ucid, c.team_leader,c.location,c.dept,
i.cph_target,i.STAR_TARGET,i.ADHERENCE_TARGET,i.CMS_DEFECT_TARGET,i.collection_call_model_defect_target,i.call_monitoring_defect_target,i.ib_aht_target
,e.defect_per,f.QC_per,j."Inbound AHT",k."Out Of"
)a )a)a
--where month>=last_day('01-JAN_24')
--where a."FUSION_ID" in ('195869')
group by a.fusion_id
)a 
) b on a.FUSION_ID=b.FUSION_ID    

where month>=last_day(period)
and a."FUSION_ID" in (vfusionid3)
order by a.month asc;            
                end if;
  END CR_SC_MTD_TL;

 
  PROCEDURE CR_SC_YTD_TL (
    vfusionid4 in VARCHAR2, p_result OUT SYS_REFCURSOR) is 
  BEGIN
      if(vfusionid4 is null) then       
            OPEN p_result FOR  
 select * from (
select 
a.fusion_id "EMPLOYEE ID"
,rank() OVER (order by sum(a."Overall Score") desc)  "Global Rank"
,sum(a."Overall Score") "Total Points"
,round(avg(a."Resolution Credits"),3) "Credit Per Hr"
,round(avg(a."Stella Star Rating"),3) "Stella Star Rating"
,round(avg(a."Schedule Adherence"),3) "Schedule Adherence"
,round(avg(a."Inbound AHT"),3) "Inbound AHT"
,round(avg(a."Cms Defect %"),3) "Cms Defect %"
,round(avg(a."TL Call Monitoring Defect"),3) "TL Call Monitoring Defect"
,round(avg(a."Collection call Model Defect"),3) "Collection call Model Defect"
from(
select 
to_char(a."MONTH",'MON-YY') "MONTH",
a."FUSION_ID",
a."UCID",
a."SUPV_NAME",
a."MANAGER_NAME",
a."LOCATION",
a."DEPT",
a."Overall Score",
a."Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from(
select 
a."MONTH",
a."FUSION_ID",
a."UCID",
a."NAME" "SUPV_NAME",
a."TEAM_LEADER" "MANAGER_NAME",
a."LOCATION",
a."DEPT",
round((a."Res Credit Points"+a."Stella Star Points"+a."Adherence Points"+a."AHT Points"+a."CMS Usage Points"
+a."TL Call Monitoring Points"+a."Collection call Model Points"),2)  "Overall Score",
rank() OVER (PARTITION by month ORDER BY round((a."Res Credit Points"+a."Stella Star Points"+a."Adherence Points"+a."AHT Points"+a."CMS Usage Points"
+a."TL Call Monitoring Points"+a."Collection call Model Points"),2) desc,month ) "Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from (
select 
--"EMPLOYEE ID"--,name,"Team Lead",location,dept
b.month,b.TL_FUSIONID "FUSION_ID",
c.ucid
,b."Team Lead" NAME, c.team_leader,c.location,c.dept
,round(avg(b."Credit Per Hr"),3) "Resolution Credits"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept ) "Res Credit Rank"
,case when round(avg(b."Credit Per Hr"),3) >2.000 then 
(case when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.15,0) then 11.25 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.6,0) then 7.5 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.85,0) then 3.75 
else 0 end )
else 0
end as "Res Credit Points"
,i.cph_target
--,round(avg(b."Quality Score"),2) "Quality Score"
--,i.QUALITY_TARGET
,round(avg(b."Stella Star Rating"),2) "Stella Star Rating"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Stella Star Rating"),2) desc,b.month,c.dept ) "Stella Star Rank"
, case when round(avg(b."Stella Star Rating"),2) >4.6 then  5-(5*0.20)
when round(avg(b."Stella Star Rating"),2) >=4.5 then  5-(5*0.40)
when round(avg(b."Stella Star Rating"),2) >=4.4 then  5-(5*0.60)
when round(avg(b."Stella Star Rating"),2) >=4.3 then  5-(5*0.80)
else 0 
end as "Stella Star Points"
,i.STAR_TARGET
,round(avg(b."Schedule Adherence"),2) "Schedule Adherence"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Schedule Adherence"),2) desc,b.month,c.dept ) "Adherence Rank"
, case when round(avg(b."Schedule Adherence"),3)>92.50 then 5-(5*0.20)
when round(avg(b."Schedule Adherence"),3)>=90.00 then 5-(5*0.40)
when round(avg(b."Schedule Adherence"),3)>=87.50 then 5-(5*0.60)
when round(avg(b."Schedule Adherence"),3)>=85.00 then 5-(5*0.80)
else 0 end as "Adherence Points"
,i.ADHERENCE_TARGET
,round(avg(b."Inbound AHT"),2) "Inbound AHT"
--,coalesce (j."Inbound AHT",0) "Inbound AHT"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Inbound AHT"),2) desc,b.month,c.dept ) "AHT Rank"
,case when round(avg(b."Inbound AHT"),2)>660 then 0
 when round(avg(b."Inbound AHT"),2) >=660 then 5-(5*0.80)
when round(avg(b."Inbound AHT"),2) >=630 then 5-(5*0.60)
when round(avg(b."Inbound AHT"),2) >=600 then 5-(5*0.40)
else 5-(5*0.20) end as "AHT Points"
,i.ib_aht_target
,round(avg(b."Cms Defect %"),2) "Cms Defect %"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Cms Defect %"),2) asc,b.month,c.dept ) "Cms Defect Rank"
,case when round(avg(b."Cms Defect %"),2) <0.5 then 18.75
when round(avg(b."Cms Defect %"),2) < 1.0 then 12.5
when round(avg(b."Cms Defect %"),2) <1.5 then 6.25
else 0
end as "CMS Usage Points"
,i.CMS_DEFECT_TARGET
,f.qc_per "TL Call Monitoring Defect"
,case when f.qc_per = 0 then  7.5
when f.qc_per <= 25 then  5
when f.qc_per <= 75 then  2.5
else 0
end as  "TL Call Monitoring Points"
,i.call_monitoring_defect_target
,e.defect_per "Collection call Model Defect"
,case when e.defect_per < 1.5 then 7.5
when e.defect_per < 2.5 then 5
when e.defect_per < 3.5 then 2.5
else 0
end as "Collection call Model Points"
,i.collection_call_model_defect_target
,k."Out Of"
from
(
select 
a.month  ,a.ucid,a."EMPLOYEE ID",a.name,a.TL_FUSIONID,a."Team Lead",a.location,a.dept
,rank() OVER (PARTITION by a.month,a.dept ORDER BY
(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") desc,a.dept,a.month ) "Global Rank"
,(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") "Total Points"
,coalesce(a."Credit Per Hr",0) "Credit Per Hr" ,a."Credit Rank",a."Credits Score",a.CPH_TARGET
, coalesce (a."Quality Score",0)  "Quality Score"
,case when a."Quality Rank" is null then 1 else a."Quality Rank" end as "Quality Rank"
,coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0) as "Quality_Score",a.QUALITY_TARGET
,coalesce(a."Stella Star Rating",0) "Stella Star Rating"
,case when a."Stella Star Rank" is null then 1 else a."Stella Star Rank" end as "Stella Star Rank"
,coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0) as "Stella Star Score",a.STAR_TARGET
,coalesce(a."Schedule Adherence",0) "Schedule Adherence",a."Adherence Rank",a."Adherence Score",a.ADHERENCE_TARGET
,coalesce(a."Inbound AHT",0) "Inbound AHT",a."AHT Rank",a."AHT Score",a.IB_AHT_TARGET
,coalesce(a."Cms Defect %",0) "Cms Defect %" ,a."Cms Defect Rank",a."Cms Defect Score",a.CMS_DEFECT_TARGET
,a."Out Of"
from
(
select 
last_day(a.month) month,
a.ucid,
a.fusionid "EMPLOYEE ID",
a.name,
a.TL_FUSIONID,
a.team_leader "Team Lead",
a.location,
a.dept
--,rank() OVER (PARTITION by last_day(a.month),a.dept ORDER BY (coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0)) desc,a.dept,last_day(a.month) ) "Global Rank"
--,(coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0))  "Total Points"
,b."Credit Per Hr",b."Credit Rank",b."Credits Score",
--b.CPH_TARGET
i.CPH_TARGET
,c."Quality Score",c."Quality Rank",c."Quality_Score"
,i.QUALITY_TARGET
,d."Stella Star Rating",d."Stella Star Rank",d."Stella Star Score"
,i.STAR_TARGET
,e."Schedule Adherence",e."Adherence Rank",e."Adherence Score"
,i.ADHERENCE_TARGET
,f."Inbound AHT",f."AHT Rank",f."AHT Score"
,i.IB_AHT_TARGET
,g."Cms Defect %",g."Cms Defect Rank",g."Cms Defect Score"
,i.CMS_DEFECT_TARGET
,h."Out Of"
from asit_roster_table a
left join(
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
--,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
,"CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
,e."CPH_TARGET"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
left join(
select month,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95","CPH_TARGET"
from (
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of"
)a )b
where "CPH_TARGET" is not null)e on last_day(a.rpt_month)=last_day(e.month) and c.dept=e.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of",e."CPH_TARGET"
)a
) b on last_day(a.month)=last_day(b.month) and a.fusionid=b.fusionid
left join(
select last_day(roster_month) month,
a.fusion_id,c.ucid,a.employee_name,c.dept
,coalesce(round(avg(score),2),0) "Quality Score"
,rank() OVER (PARTITION by last_day(roster_month),c.dept ORDER BY coalesce(round(avg(score),2),0) desc,c.dept,last_day(roster_month) )  "Quality Rank"
,b."Out Of"
,case 
when coalesce(round(avg(score),2),0) >=97.50  then 3.75 
when coalesce(round(avg(score),2),0) >=95.20  then 2.5
when coalesce(round(avg(score),2),0) >=90  then 1.25 
else 0
end as
"Quality_Score"
from asit_quality a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.roster_month)=c.month and a.fusion_id=c.fusionid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.roster_month)=b.monthn and b.dept=c.dept
--where a.roster_month=last_day('31-JAN-24') 
--and a.ucid in (select distinct ucid from asit_roster_table where fusionid='105554' ) 
group by last_day(roster_month),a.fusion_id,c.ucid,a.employee_name,c.dept,b."Out Of"

)c on last_day(a.month)=last_day(c.month) and a.fusionid=c.fusion_id
left join(
select 
last_day(a.month) month,a.employee_custom_id,c.dept
--,a.team_leader
,coalesce(round(avg(star_rating),2),0) "Stella Star Rating"
,rank() OVER (PARTITION by last_day(a.month),c.dept  ORDER BY coalesce(round(avg(star_rating),2),0) desc,c.dept ,last_day(a.month) ) "Stella Star Rank"
,b."Out Of"
,case when coalesce(round(avg(star_rating),2),0) >= 4.6 then 4.00
when coalesce(round(avg(star_rating),2),0) >= 4.5 then 3.00 
when coalesce(round(avg(star_rating),2),0) >= 4.4 then 2.00
when coalesce(round(avg(star_rating),2),0) >= 4.3 then 1.00
else 0
end as "Stella Star Score"
from asit_star_rating a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.employee_custom_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
--where  a.month=last_day(a.month)
--and employee_custom_id in ('196400') 
group by last_day(a.month),c.dept,a.employee_custom_id,b."Out Of"
)d on last_day(a.month)=last_day(d.month) and a.fusionid=d.employee_custom_id
left join (
select 
last_day(a.month) month,a.fusion_id,c.dept 
,coalesce(round(adherence_percentage*100,2),0) "Schedule Adherence"
,rank() OVER (PARTITION by last_day(a.month),c.dept ORDER BY coalesce(round(adherence_percentage*100,2),0) desc,c.dept ,last_day(a.month) ) "Adherence Rank"
,b."Out Of"
,case when coalesce(round(adherence_percentage*100,2),0) >=95 then 4.00 
when coalesce(round(adherence_percentage*100,2),0) >=92.5 then 3.00
when coalesce(round(adherence_percentage*100,2),0) >=90 then 2.00 
when coalesce(round(adherence_percentage*100,2),0) >=87.5 then 1.00
else 0
end as
"Adherence Score"
from asit_telephony a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.fusion_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)e on last_day(a.month)=last_day(e.month) and a.fusionid=e.fusion_id
left join (
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
)f on to_char(last_day(a.month),'MON-YY')=f.month and a.fusionid=f.fusionid
left join(
select 
last_day(a.month) month,c.fusionid,a.ucid,c.dept,a.cms_defect_percentage,coalesce(round(a.cms_defect_percentage*100,2),0) "Cms Defect %"
,rank() OVER (PARTITION by a.month ORDER BY coalesce(round(a.cms_defect_percentage*100,2),0) asc,a.month ) "Cms Defect Rank"
,b."Out Of"
,case when coalesce(round(a.cms_defect_percentage*100,2),0) <0.5 then 18.5 
when coalesce(round(a.cms_defect_percentage*100,2),0) <1 then 12.5
when coalesce(round(a.cms_defect_percentage*100,2),0) <=1.5 then 6.25
else 0
end as
"Cms Defect Score"
from asit_cms_defect a
join(
select month,fusionid,ucid,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.ucid=c.ucid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)g on last_day(a.month)=g.month and a.fusionid=g.fusionid
left join(
select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)h on last_day(a.month)=h.monthn and a.dept=h.dept
left join CR_SC_AGNTS_TARGET i on last_day(a.month)=i.month and a.dept=i.dept
where --a.month>=last_day(sysdate)and
 a.dept in ('CCC-R','CCC-R SPANISH','FLEX')
and a.location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and a.designation in ('Agent')
and a.final_status='ACTIVE'
and a.team_leader not in (select name from not_teamleader)
)a)b
join(
select month,fusionid,ucid,name,TL_FUSIONID,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on b.month=c.month and b.TL_FUSIONID=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)d on b.month=d.monthn and c.dept=d.dept
left join (
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end defect_per 
 from asit_tl_impact
)e on b.month=e.month and b.TL_FUSIONID=e.fusionid
left join(
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end QC_per 
 from asit_tl_qc
)f on b.month=f.month and b.TL_FUSIONID=f.fusionid
left join CR_SC_TL_TARGET i on b.month=i.month and c.dept=i.dept
left join(
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept

) j on to_char(b.month,'MON-YY')=j.month and b.TL_FUSIONID=j.fusionid
left join (select 
to_char(last_day(month),'MON-YY') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-YY'),dept
)k on to_char(b.month,'MON-YY')=k.monthn and c.dept=k.dept
--where  "EMPLOYEE ID" in('197233')
group by b.month,b.TL_FUSIONID,b."Team Lead"
,c.fusionid,c.ucid, c.team_leader,c.location,c.dept,
i.cph_target,i.STAR_TARGET,i.ADHERENCE_TARGET,i.CMS_DEFECT_TARGET,i.collection_call_model_defect_target,i.call_monitoring_defect_target,i.ib_aht_target
,e.defect_per,f.QC_per,j."Inbound AHT",k."Out Of"
)a )a)a
--where month>=last_day('01-JAN_24')
--where a."FUSION_ID" in ('195869')
group by a.fusion_id
)a 
--where fusion_id in ('101800')
order by a."Global Rank" asc
;

else 
 open p_result for
    
 select * from (
select 
a.fusion_id "EMPLOYEE ID"
,rank() OVER (order by sum(a."Overall Score") desc)  "Global Rank"
,sum(a."Overall Score") "Total Points"
,round(avg(a."Resolution Credits"),3) "Credit Per Hr"
,round(avg(a."Stella Star Rating"),3) "Stella Star Rating"
,round(avg(a."Schedule Adherence"),3) "Schedule Adherence"
,round(avg(a."Inbound AHT"),3) "Inbound AHT"
,round(avg(a."Cms Defect %"),3) "Cms Defect %"
,round(avg(a."TL Call Monitoring Defect"),3) "TL Call Monitoring Defect"
,round(avg(a."Collection call Model Defect"),3) "Collection call Model Defect"
from(
select 
to_char(a."MONTH",'MON-YY') "MONTH",
a."FUSION_ID",
a."UCID",
a."SUPV_NAME",
a."MANAGER_NAME",
a."LOCATION",
a."DEPT",
a."Overall Score",
a."Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from(
select 
a."MONTH",
a."FUSION_ID",
a."UCID",
a."NAME" "SUPV_NAME",
a."TEAM_LEADER" "MANAGER_NAME",
a."LOCATION",
a."DEPT",
round((a."Res Credit Points"+a."Stella Star Points"+a."Adherence Points"+a."AHT Points"+a."CMS Usage Points"
+a."TL Call Monitoring Points"+a."Collection call Model Points"),2)  "Overall Score",
rank() OVER (PARTITION by month ORDER BY round((a."Res Credit Points"+a."Stella Star Points"+a."Adherence Points"+a."AHT Points"+a."CMS Usage Points"
+a."TL Call Monitoring Points"+a."Collection call Model Points"),2) desc,month ) "Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from (
select 
--"EMPLOYEE ID"--,name,"Team Lead",location,dept
b.month,b.TL_FUSIONID "FUSION_ID",
c.ucid
,b."Team Lead" NAME, c.team_leader,c.location,c.dept
,round(avg(b."Credit Per Hr"),3) "Resolution Credits"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept ) "Res Credit Rank"
,case when round(avg(b."Credit Per Hr"),3) >2.000 then 
(case when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.15,0) then 11.25 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.6,0) then 7.5 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.85,0) then 3.75 
else 0 end )
else 0
end as "Res Credit Points"
,i.cph_target
--,round(avg(b."Quality Score"),2) "Quality Score"
--,i.QUALITY_TARGET
,round(avg(b."Stella Star Rating"),2) "Stella Star Rating"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Stella Star Rating"),2) desc,b.month,c.dept ) "Stella Star Rank"
, case when round(avg(b."Stella Star Rating"),2) >4.6 then  5-(5*0.20)
when round(avg(b."Stella Star Rating"),2) >=4.5 then  5-(5*0.40)
when round(avg(b."Stella Star Rating"),2) >=4.4 then  5-(5*0.60)
when round(avg(b."Stella Star Rating"),2) >=4.3 then  5-(5*0.80)
else 0 
end as "Stella Star Points"
,i.STAR_TARGET
,round(avg(b."Schedule Adherence"),2) "Schedule Adherence"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Schedule Adherence"),2) desc,b.month,c.dept ) "Adherence Rank"
, case when round(avg(b."Schedule Adherence"),3)>92.50 then 5-(5*0.20)
when round(avg(b."Schedule Adherence"),3)>=90.00 then 5-(5*0.40)
when round(avg(b."Schedule Adherence"),3)>=87.50 then 5-(5*0.60)
when round(avg(b."Schedule Adherence"),3)>=85.00 then 5-(5*0.80)
else 0 end as "Adherence Points"
,i.ADHERENCE_TARGET
,round(avg(b."Inbound AHT"),2) "Inbound AHT"
--,coalesce (j."Inbound AHT",0) "Inbound AHT"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Inbound AHT"),2) desc,b.month,c.dept ) "AHT Rank"
,case when round(avg(b."Inbound AHT"),2)>660 then 0
 when round(avg(b."Inbound AHT"),2) >=660 then 5-(5*0.80)
when round(avg(b."Inbound AHT"),2) >=630 then 5-(5*0.60)
when round(avg(b."Inbound AHT"),2) >=600 then 5-(5*0.40)
else 5-(5*0.20) end as "AHT Points"
,i.ib_aht_target
,round(avg(b."Cms Defect %"),2) "Cms Defect %"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Cms Defect %"),2) asc,b.month,c.dept ) "Cms Defect Rank"
,case when round(avg(b."Cms Defect %"),2) <0.5 then 18.75
when round(avg(b."Cms Defect %"),2) < 1.0 then 12.5
when round(avg(b."Cms Defect %"),2) <1.5 then 6.25
else 0
end as "CMS Usage Points"
,i.CMS_DEFECT_TARGET
,f.qc_per "TL Call Monitoring Defect"
,case when f.qc_per = 0 then  7.5
when f.qc_per <= 25 then  5
when f.qc_per <= 75 then  2.5
else 0
end as  "TL Call Monitoring Points"
,i.call_monitoring_defect_target
,e.defect_per "Collection call Model Defect"
,case when e.defect_per < 1.5 then 7.5
when e.defect_per < 2.5 then 5
when e.defect_per < 3.5 then 2.5
else 0
end as "Collection call Model Points"
,i.collection_call_model_defect_target
,k."Out Of"
from
(
select 
a.month  ,a.ucid,a."EMPLOYEE ID",a.name,a.TL_FUSIONID,a."Team Lead",a.location,a.dept
,rank() OVER (PARTITION by a.month,a.dept ORDER BY
(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") desc,a.dept,a.month ) "Global Rank"
,(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") "Total Points"
,coalesce(a."Credit Per Hr",0) "Credit Per Hr" ,a."Credit Rank",a."Credits Score",a.CPH_TARGET
, coalesce (a."Quality Score",0)  "Quality Score"
,case when a."Quality Rank" is null then 1 else a."Quality Rank" end as "Quality Rank"
,coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0) as "Quality_Score",a.QUALITY_TARGET
,coalesce(a."Stella Star Rating",0) "Stella Star Rating"
,case when a."Stella Star Rank" is null then 1 else a."Stella Star Rank" end as "Stella Star Rank"
,coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0) as "Stella Star Score",a.STAR_TARGET
,coalesce(a."Schedule Adherence",0) "Schedule Adherence",a."Adherence Rank",a."Adherence Score",a.ADHERENCE_TARGET
,coalesce(a."Inbound AHT",0) "Inbound AHT",a."AHT Rank",a."AHT Score",a.IB_AHT_TARGET
,coalesce(a."Cms Defect %",0) "Cms Defect %" ,a."Cms Defect Rank",a."Cms Defect Score",a.CMS_DEFECT_TARGET
,a."Out Of"
from
(
select 
last_day(a.month) month,
a.ucid,
a.fusionid "EMPLOYEE ID",
a.name,
a.TL_FUSIONID,
a.team_leader "Team Lead",
a.location,
a.dept
--,rank() OVER (PARTITION by last_day(a.month),a.dept ORDER BY (coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0)) desc,a.dept,last_day(a.month) ) "Global Rank"
--,(coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0))  "Total Points"
,b."Credit Per Hr",b."Credit Rank",b."Credits Score",
--b.CPH_TARGET
i.CPH_TARGET
,c."Quality Score",c."Quality Rank",c."Quality_Score"
,i.QUALITY_TARGET
,d."Stella Star Rating",d."Stella Star Rank",d."Stella Star Score"
,i.STAR_TARGET
,e."Schedule Adherence",e."Adherence Rank",e."Adherence Score"
,i.ADHERENCE_TARGET
,f."Inbound AHT",f."AHT Rank",f."AHT Score"
,i.IB_AHT_TARGET
,g."Cms Defect %",g."Cms Defect Rank",g."Cms Defect Score"
,i.CMS_DEFECT_TARGET
,h."Out Of"
from asit_roster_table a
left join(
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
--,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
,"CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
,e."CPH_TARGET"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
left join(
select month,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95","CPH_TARGET"
from (
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of"
)a )b
where "CPH_TARGET" is not null)e on last_day(a.rpt_month)=last_day(e.month) and c.dept=e.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of",e."CPH_TARGET"
)a
) b on last_day(a.month)=last_day(b.month) and a.fusionid=b.fusionid
left join(
select last_day(roster_month) month,
a.fusion_id,c.ucid,a.employee_name,c.dept
,coalesce(round(avg(score),2),0) "Quality Score"
,rank() OVER (PARTITION by last_day(roster_month),c.dept ORDER BY coalesce(round(avg(score),2),0) desc,c.dept,last_day(roster_month) )  "Quality Rank"
,b."Out Of"
,case 
when coalesce(round(avg(score),2),0) >=97.50  then 3.75 
when coalesce(round(avg(score),2),0) >=95.20  then 2.5
when coalesce(round(avg(score),2),0) >=90  then 1.25 
else 0
end as
"Quality_Score"
from asit_quality a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.roster_month)=c.month and a.fusion_id=c.fusionid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.roster_month)=b.monthn and b.dept=c.dept
--where a.roster_month=last_day('31-JAN-24') 
--and a.ucid in (select distinct ucid from asit_roster_table where fusionid='105554' ) 
group by last_day(roster_month),a.fusion_id,c.ucid,a.employee_name,c.dept,b."Out Of"

)c on last_day(a.month)=last_day(c.month) and a.fusionid=c.fusion_id
left join(
select 
last_day(a.month) month,a.employee_custom_id,c.dept
--,a.team_leader
,coalesce(round(avg(star_rating),2),0) "Stella Star Rating"
,rank() OVER (PARTITION by last_day(a.month),c.dept  ORDER BY coalesce(round(avg(star_rating),2),0) desc,c.dept ,last_day(a.month) ) "Stella Star Rank"
,b."Out Of"
,case when coalesce(round(avg(star_rating),2),0) >= 4.6 then 4.00
when coalesce(round(avg(star_rating),2),0) >= 4.5 then 3.00 
when coalesce(round(avg(star_rating),2),0) >= 4.4 then 2.00
when coalesce(round(avg(star_rating),2),0) >= 4.3 then 1.00
else 0
end as "Stella Star Score"
from asit_star_rating a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.employee_custom_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
--where  a.month=last_day(a.month)
--and employee_custom_id in ('196400') 
group by last_day(a.month),c.dept,a.employee_custom_id,b."Out Of"
)d on last_day(a.month)=last_day(d.month) and a.fusionid=d.employee_custom_id
left join (
select 
last_day(a.month) month,a.fusion_id,c.dept 
,coalesce(round(adherence_percentage*100,2),0) "Schedule Adherence"
,rank() OVER (PARTITION by last_day(a.month),c.dept ORDER BY coalesce(round(adherence_percentage*100,2),0) desc,c.dept ,last_day(a.month) ) "Adherence Rank"
,b."Out Of"
,case when coalesce(round(adherence_percentage*100,2),0) >=95 then 4.00 
when coalesce(round(adherence_percentage*100,2),0) >=92.5 then 3.00
when coalesce(round(adherence_percentage*100,2),0) >=90 then 2.00 
when coalesce(round(adherence_percentage*100,2),0) >=87.5 then 1.00
else 0
end as
"Adherence Score"
from asit_telephony a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.fusion_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)e on last_day(a.month)=last_day(e.month) and a.fusionid=e.fusion_id
left join (
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
)f on to_char(last_day(a.month),'MON-YY')=f.month and a.fusionid=f.fusionid
left join(
select 
last_day(a.month) month,c.fusionid,a.ucid,c.dept,a.cms_defect_percentage,coalesce(round(a.cms_defect_percentage*100,2),0) "Cms Defect %"
,rank() OVER (PARTITION by a.month ORDER BY coalesce(round(a.cms_defect_percentage*100,2),0) asc,a.month ) "Cms Defect Rank"
,b."Out Of"
,case when coalesce(round(a.cms_defect_percentage*100,2),0) <0.5 then 18.5 
when coalesce(round(a.cms_defect_percentage*100,2),0) <1 then 12.5
when coalesce(round(a.cms_defect_percentage*100,2),0) <=1.5 then 6.25
else 0
end as
"Cms Defect Score"
from asit_cms_defect a
join(
select month,fusionid,ucid,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.ucid=c.ucid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)g on last_day(a.month)=g.month and a.fusionid=g.fusionid
left join(
select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)h on last_day(a.month)=h.monthn and a.dept=h.dept
left join CR_SC_AGNTS_TARGET i on last_day(a.month)=i.month and a.dept=i.dept
where --a.month>=last_day(sysdate)and
 a.dept in ('CCC-R','CCC-R SPANISH','FLEX')
and a.location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and a.designation in ('Agent')
and a.final_status='ACTIVE'
and a.team_leader not in (select name from not_teamleader)
)a)b
join(
select month,fusionid,ucid,name,TL_FUSIONID,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on b.month=c.month and b.TL_FUSIONID=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)d on b.month=d.monthn and c.dept=d.dept
left join (
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end defect_per 
 from asit_tl_impact
)e on b.month=e.month and b.TL_FUSIONID=e.fusionid
left join(
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end QC_per 
 from asit_tl_qc
)f on b.month=f.month and b.TL_FUSIONID=f.fusionid
left join CR_SC_TL_TARGET i on b.month=i.month and c.dept=i.dept
left join(
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept

) j on to_char(b.month,'MON-YY')=j.month and b.TL_FUSIONID=j.fusionid
left join (select 
to_char(last_day(month),'MON-YY') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-YY'),dept
)k on to_char(b.month,'MON-YY')=k.monthn and c.dept=k.dept
--where  "EMPLOYEE ID" in('197233')
group by b.month,b.TL_FUSIONID,b."Team Lead"
,c.fusionid,c.ucid, c.team_leader,c.location,c.dept,
i.cph_target,i.STAR_TARGET,i.ADHERENCE_TARGET,i.CMS_DEFECT_TARGET,i.collection_call_model_defect_target,i.call_monitoring_defect_target,i.ib_aht_target
,e.defect_per,f.QC_per,j."Inbound AHT",k."Out Of"
)a )a)a
--where month>=last_day('01-JAN_24')
--where a."FUSION_ID" in ('195869')
group by a.fusion_id
)a 
where "EMPLOYEE ID" in (vfusionid4)
order by a."Global Rank" asc
;  

 
 end if;
 
END CR_SC_YTD_TL; 
  
PROCEDURE CR_SC_MTD_AM (
    per in VARCHAR2,vfusionid5 in VARCHAR2, p_result OUT SYS_REFCURSOR) 
    is 
    period date;
  BEGIN
    -- TODO: Implementation required for PROCEDURE CR_SC_MTD_AGNTS.CR_SC_MTD_AGNTS
      period:=to_date(per,'yyyy-MM-dd');
      --vfusionid:='196035';
         dbms_output.put_line('period =' || period);
         
         
     if(vfusionid5 is null and period is null ) then
            OPEN p_result FOR  
     


select 
to_char(a."MONTH",'MON-YY') MONTH,
a."UCID",
a."FUSION_ID",
a."ASM_NAME",
a."MANAGER",
a."LOCATION",
a."DEPT",
a."Overall Rank",
a."Overall Score",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Inbound AHT",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Off",
b."YTD Global Rank",
b."YTD Global Total Score"
from(
select 
a."MONTH",
a."UCID",
a."FUSION_ID",
a."ASM_NAME",
a."MANAGER",
a."LOCATION",
a."DEPT",
rank() OVER (PARTITION by a."MONTH",a."DEPT" ORDER BY (round( coalesce(a."Res Credit Points",0) + coalesce(a."AHT Points",0) + coalesce(a."CMS Usage Points",0)+ coalesce(a."TL Call Monitoring Points",0) +
coalesce(a."Collection call Model Points",0)
,2)) desc,a."MONTH",a."DEPT" ) "Overall Rank",
(round( coalesce(a."Res Credit Points",0) + coalesce(a."AHT Points",0) + coalesce(a."CMS Usage Points",0)+ coalesce(a."TL Call Monitoring Points",0) +
coalesce(a."Collection call Model Points",0)
,2))"Overall Score",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Inbound AHT",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Off"
from (
select 
a.month,c.ucid,a."TL FUSION_ID" "FUSION_ID",c.name "ASM_NAME",c.team_leader "MANAGER",c.location,c.dept,
round(avg(a."Resolution Credits"),2) "Resolution Credits",
rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept ) "Res Credit Rank",
case when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept ) =1 
then 7.5
when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )=2
then 5
else 2.5 end as "Res Credit Points",
/*case when round(avg(a."Resolution Credits"),2) < 2 then 0 else
(case when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )
<=round(d."Out Off"*0.15,0) then 7.5
when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )
<=round(d."Out Off"*0.6,0) then 5 
when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )
<=round(d."Out Off"*0.85,0) then 2.5 
else 0 end )
end as  "Res Credit Points",*/
e.cph_target,
round(avg(a."Inbound AHT"),2) "Inbound AHT",

case when round(avg(a."Inbound AHT"),2) > 660 then 0
 when round(avg(a."Inbound AHT"),2) >=660 then 5-(5*0.80)
when round(avg(a."Inbound AHT"),2) >=630 then 5-(5*0.60)
when round(avg(a."Inbound AHT"),2) >=600 then 5-(5*0.40)
else 5-(5*0.20) end as "AHT Points",
e.ib_aht_target,
round(avg(a."Cms Defect %"),2) "Cms Defect %",
case when round(avg(a."Cms Defect %"),2) <0.5 then 18.75
when round(avg(a."Cms Defect %"),2) < 1.0 then 12.5
when round(avg(a."Cms Defect %"),2) <1.5 then 6.25
else 0
end as "CMS Usage Points",

e.cms_defect_target,
round(avg(a."TL Call Monitoring Defect"),2) "TL Call Monitoring Defect",
case when round(avg(a."TL Call Monitoring Defect"),2) =0 then 3.75
 when round(avg(a."TL Call Monitoring Defect"),2) <= 25 then 2.5 
  when round(avg(a."TL Call Monitoring Defect"),2) <=75  then 1.25
else 0
end as "TL Call Monitoring Points",
e.call_monitoring_defect_target,
round(avg(a."Collection call Model Defect"),2) "Collection call Model Defect",
case when round(avg(a."Collection call Model Defect"),2) < 1.5 then 7.5
when round(avg(a."Collection call Model Defect"),2) < 2.5 then 5
when round(avg(a."Collection call Model Defect"),2) < 3.5 then 2.5
else 0
end "Collection call Model Points",
e.collection_call_model_defect_target,
d."Out Off"
from (
select 
a."MONTH",
a."FUSION_ID",
a."UCID",
a."SUPV_NAME",a."TL FUSION_ID",
a."MANAGER_NAME",
a."LOCATION",
a."DEPT",
a."Overall Score",
a."Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from(
select 
a."MONTH",
a."FUSION_ID",
a."UCID",
a."NAME" "SUPV_NAME",a."TL FUSION_ID",
a."TEAM_LEADER" "MANAGER_NAME",
a."LOCATION",
a."DEPT",
round((a."Res Credit Points"+a."Stella Star Points"+a."Adherence Points"+a."AHT Points"+a."CMS Usage Points"
+a."TL Call Monitoring Points"+a."Collection call Model Points"),2)  "Overall Score",
rank() OVER (PARTITION by month ORDER BY round((a."Res Credit Points"+a."Stella Star Points"+a."Adherence Points"+a."AHT Points"+a."CMS Usage Points"
+a."TL Call Monitoring Points"+a."Collection call Model Points"),2) desc,month ) "Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from (
select 
--"EMPLOYEE ID"--,name,"Team Lead",location,dept
b.month,b.TL_FUSIONID "FUSION_ID",
c.ucid
,b."Team Lead" NAME,c.TL_FUSIONID "TL FUSION_ID", c.team_leader,c.location,c.dept
,round(avg(b."Credit Per Hr"),3) "Resolution Credits"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept ) "Res Credit Rank"
,case when round(avg(b."Credit Per Hr"),3) >2.000 then 
(case when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.15,0) then 11.25 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.6,0) then 7.5 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.85,0) then 3.75 
else 0 end )
else 0
end as "Res Credit Points"
,i.cph_target
--,round(avg(b."Quality Score"),2) "Quality Score"
--,i.QUALITY_TARGET
,round(avg(b."Stella Star Rating"),2) "Stella Star Rating"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Stella Star Rating"),2) desc,b.month,c.dept ) "Stella Star Rank"
, case when round(avg(b."Stella Star Rating"),2) >4.6 then  5-(5*0.20)
when round(avg(b."Stella Star Rating"),2) >=4.5 then  5-(5*0.40)
when round(avg(b."Stella Star Rating"),2) >=4.4 then  5-(5*0.60)
when round(avg(b."Stella Star Rating"),2) >=4.3 then  5-(5*0.80)
else 0 
end as "Stella Star Points"
,i.STAR_TARGET
,round(avg(b."Schedule Adherence"),2) "Schedule Adherence"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Schedule Adherence"),2) desc,b.month,c.dept ) "Adherence Rank"
, case when round(avg(b."Schedule Adherence"),3)>92.50 then 5-(5*0.20)
when round(avg(b."Schedule Adherence"),3)>=90.00 then 5-(5*0.40)
when round(avg(b."Schedule Adherence"),3)>=87.50 then 5-(5*0.60)
when round(avg(b."Schedule Adherence"),3)>=85.00 then 5-(5*0.80)
else 0 end as "Adherence Points"
,i.ADHERENCE_TARGET
,round(avg(b."Inbound AHT"),2) "Inbound AHT"
--,coalesce (j."Inbound AHT",0) "Inbound AHT"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Inbound AHT"),2) desc,b.month,c.dept ) "AHT Rank"
,case when round(avg(b."Inbound AHT"),2)>660 then 0
 when round(avg(b."Inbound AHT"),2) >=660 then 5-(5*0.80)
when round(avg(b."Inbound AHT"),2) >=630 then 5-(5*0.60)
when round(avg(b."Inbound AHT"),2) >=600 then 5-(5*0.40)
else 5-(5*0.20) end as "AHT Points"
,i.ib_aht_target
,round(avg(b."Cms Defect %"),2) "Cms Defect %"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Cms Defect %"),2) asc,b.month,c.dept ) "Cms Defect Rank"
,case when round(avg(b."Cms Defect %"),2) <0.5 then 18.75
when round(avg(b."Cms Defect %"),2) < 1.0 then 12.5
when round(avg(b."Cms Defect %"),2) <1.5 then 6.25
else 0
end as "CMS Usage Points"
,i.CMS_DEFECT_TARGET
,f.qc_per "TL Call Monitoring Defect"
,case when f.qc_per = 0 then  7.5
when f.qc_per <= 25 then  5
when f.qc_per <= 75 then  2.5
else 0
end as  "TL Call Monitoring Points"
,i.call_monitoring_defect_target
,e.defect_per "Collection call Model Defect"
,case when e.defect_per < 1.5 then 7.5
when e.defect_per < 2.5 then 5
when e.defect_per < 3.5 then 2.5
else 0
end as "Collection call Model Points"
,i.collection_call_model_defect_target
,k."Out Of"
from
(
select 
a.month  ,a.ucid,a."EMPLOYEE ID",a.name,a.TL_FUSIONID,a."Team Lead",a.location,a.dept
,rank() OVER (PARTITION by a.month,a.dept ORDER BY
(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") desc,a.dept,a.month ) "Global Rank"
,(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") "Total Points"
,coalesce(a."Credit Per Hr",0) "Credit Per Hr" ,a."Credit Rank",a."Credits Score",a.CPH_TARGET
, coalesce (a."Quality Score",0)  "Quality Score"
,case when a."Quality Rank" is null then 1 else a."Quality Rank" end as "Quality Rank"
,coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0) as "Quality_Score",a.QUALITY_TARGET
,coalesce(a."Stella Star Rating",0) "Stella Star Rating"
,case when a."Stella Star Rank" is null then 1 else a."Stella Star Rank" end as "Stella Star Rank"
,coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0) as "Stella Star Score",a.STAR_TARGET
,coalesce(a."Schedule Adherence",0) "Schedule Adherence",a."Adherence Rank",a."Adherence Score",a.ADHERENCE_TARGET
,coalesce(a."Inbound AHT",0) "Inbound AHT",a."AHT Rank",a."AHT Score",a.IB_AHT_TARGET
,coalesce(a."Cms Defect %",0) "Cms Defect %" ,a."Cms Defect Rank",a."Cms Defect Score",a.CMS_DEFECT_TARGET
,a."Out Of"
from
(
select 
last_day(a.month) month,
a.ucid,
a.fusionid "EMPLOYEE ID",
a.name,
a.TL_FUSIONID,
a.team_leader "Team Lead",
a.location,
a.dept
--,rank() OVER (PARTITION by last_day(a.month),a.dept ORDER BY (coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0)) desc,a.dept,last_day(a.month) ) "Global Rank"
--,(coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0))  "Total Points"
,b."Credit Per Hr",b."Credit Rank",b."Credits Score",
--b.CPH_TARGET
i.CPH_TARGET
,c."Quality Score",c."Quality Rank",c."Quality_Score"
,i.QUALITY_TARGET
,d."Stella Star Rating",d."Stella Star Rank",d."Stella Star Score"
,i.STAR_TARGET
,e."Schedule Adherence",e."Adherence Rank",e."Adherence Score"
,i.ADHERENCE_TARGET
,f."Inbound AHT",f."AHT Rank",f."AHT Score"
,i.IB_AHT_TARGET
,g."Cms Defect %",g."Cms Defect Rank",g."Cms Defect Score"
,i.CMS_DEFECT_TARGET
,h."Out Of"
from asit_roster_table a
left join(
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
--,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
,"CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
,e."CPH_TARGET"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
left join(
select month,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95","CPH_TARGET"
from (
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of"
)a )b
where "CPH_TARGET" is not null)e on last_day(a.rpt_month)=last_day(e.month) and c.dept=e.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of",e."CPH_TARGET"
)a
) b on last_day(a.month)=last_day(b.month) and a.fusionid=b.fusionid
left join(
select last_day(roster_month) month,
a.fusion_id,c.ucid,a.employee_name,c.dept
,coalesce(round(avg(score),2),0) "Quality Score"
,rank() OVER (PARTITION by last_day(roster_month),c.dept ORDER BY coalesce(round(avg(score),2),0) desc,c.dept,last_day(roster_month) )  "Quality Rank"
,b."Out Of"
,case 
when coalesce(round(avg(score),2),0) >=97.50  then 3.75 
when coalesce(round(avg(score),2),0) >=95.20  then 2.5
when coalesce(round(avg(score),2),0) >=90  then 1.25 
else 0
end as
"Quality_Score"
from asit_quality a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.roster_month)=c.month and a.fusion_id=c.fusionid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.roster_month)=b.monthn and b.dept=c.dept
--where a.roster_month=last_day('31-JAN-24') 
--and a.ucid in (select distinct ucid from asit_roster_table where fusionid='105554' ) 
group by last_day(roster_month),a.fusion_id,c.ucid,a.employee_name,c.dept,b."Out Of"

)c on last_day(a.month)=last_day(c.month) and a.fusionid=c.fusion_id
left join(
select 
last_day(a.month) month,a.employee_custom_id,c.dept
--,a.team_leader
,coalesce(round(avg(star_rating),2),0) "Stella Star Rating"
,rank() OVER (PARTITION by last_day(a.month),c.dept  ORDER BY coalesce(round(avg(star_rating),2),0) desc,c.dept ,last_day(a.month) ) "Stella Star Rank"
,b."Out Of"
,case when coalesce(round(avg(star_rating),2),0) >= 4.6 then 4.00
when coalesce(round(avg(star_rating),2),0) >= 4.5 then 3.00 
when coalesce(round(avg(star_rating),2),0) >= 4.4 then 2.00
when coalesce(round(avg(star_rating),2),0) >= 4.3 then 1.00
else 0
end as "Stella Star Score"
from asit_star_rating a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.employee_custom_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
--where  a.month=last_day(a.month)
--and employee_custom_id in ('196400') 
group by last_day(a.month),c.dept,a.employee_custom_id,b."Out Of"
)d on last_day(a.month)=last_day(d.month) and a.fusionid=d.employee_custom_id
left join (
select 
last_day(a.month) month,a.fusion_id,c.dept 
,coalesce(round(adherence_percentage*100,2),0) "Schedule Adherence"
,rank() OVER (PARTITION by last_day(a.month),c.dept ORDER BY coalesce(round(adherence_percentage*100,2),0) desc,c.dept ,last_day(a.month) ) "Adherence Rank"
,b."Out Of"
,case when coalesce(round(adherence_percentage*100,2),0) >=95 then 4.00 
when coalesce(round(adherence_percentage*100,2),0) >=92.5 then 3.00
when coalesce(round(adherence_percentage*100,2),0) >=90 then 2.00 
when coalesce(round(adherence_percentage*100,2),0) >=87.5 then 1.00
else 0
end as
"Adherence Score"
from asit_telephony a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.fusion_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)e on last_day(a.month)=last_day(e.month) and a.fusionid=e.fusion_id
left join (
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
)f on to_char(last_day(a.month),'MON-YY')=f.month and a.fusionid=f.fusionid
left join(
select 
last_day(a.month) month,c.fusionid,a.ucid,c.dept,a.cms_defect_percentage,coalesce(round(a.cms_defect_percentage*100,2),0) "Cms Defect %"
,rank() OVER (PARTITION by a.month ORDER BY coalesce(round(a.cms_defect_percentage*100,2),0) asc,a.month ) "Cms Defect Rank"
,b."Out Of"
,case when coalesce(round(a.cms_defect_percentage*100,2),0) <0.5 then 18.5 
when coalesce(round(a.cms_defect_percentage*100,2),0) <1 then 12.5
when coalesce(round(a.cms_defect_percentage*100,2),0) <=1.5 then 6.25
else 0
end as
"Cms Defect Score"
from asit_cms_defect a
join(
select month,fusionid,ucid,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.ucid=c.ucid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)g on last_day(a.month)=g.month and a.fusionid=g.fusionid
left join(
select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)h on last_day(a.month)=h.monthn and a.dept=h.dept
left join CR_SC_AGNTS_TARGET i on last_day(a.month)=i.month and a.dept=i.dept
where --a.month>=last_day(sysdate)and
 a.dept in ('CCC-R','CCC-R SPANISH','FLEX')
and a.location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and a.designation in ('Agent')
and a.final_status='ACTIVE'
and a.team_leader not in (select name from not_teamleader)
)a)b
join(
select month,fusionid,ucid,name,TL_FUSIONID,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on b.month=c.month and b.TL_FUSIONID=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)d on b.month=d.monthn and c.dept=d.dept
left join (
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end defect_per 
 from asit_tl_impact
)e on b.month=e.month and b.TL_FUSIONID=e.fusionid
left join(
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end QC_per 
 from asit_tl_qc
)f on b.month=f.month and b.TL_FUSIONID=f.fusionid
left join CR_SC_TL_TARGET i on b.month=i.month and c.dept=i.dept
left join(
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept

) j on to_char(b.month,'MON-YY')=j.month and b.TL_FUSIONID=j.fusionid
left join (select 
to_char(last_day(month),'MON-YY') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-YY'),dept
)k on to_char(b.month,'MON-YY')=k.monthn and c.dept=k.dept
--where  "EMPLOYEE ID" in('197233')
group by b.month,b.TL_FUSIONID,b."Team Lead"
,c.fusionid,c.ucid,c.TL_FUSIONID ,c.team_leader,c.location,c.dept,
i.cph_target,i.STAR_TARGET,i.ADHERENCE_TARGET,i.CMS_DEFECT_TARGET,i.collection_call_model_defect_target,i.call_monitoring_defect_target,i.ib_aht_target
,e.defect_per,f.QC_per,j."Inbound AHT",k."Out Of"
)a )a ) a 
join(
select month,fusionid,ucid,name,TL_FUSIONID,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Assistant Manager')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a."TL FUSION_ID"=c.fusionid
join(
select month,dept,count(fusionid) "Out Off" from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Assistant Manager')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by  month,dept
)d on a.month=d.month
left join CR_SC_AM_TARGET e on a.month=e.month and c.dept=e.dept
--where a.month>=last_day('01-JAN_24')
--where a."FUSION_ID" in ('195869')
group by a.month,a."TL FUSION_ID",a."MANAGER_NAME",c.ucid,c.name,c.team_leader,c.location,c.dept,d."Out Off"
,e.cph_target,e.ib_aht_target,e.cms_defect_target,e.call_monitoring_defect_target,e.collection_call_model_defect_target
)a ) a 
left join(
select 
/*a."MONTH",
a."UCID",*/
a."FUSION_ID",
/*a."ASM_NAME",
a."MANAGER",
a."LOCATION",
a."DEPT",*/
rank() OVER (order by sum(a."Overall Score") desc,a."FUSION_ID") "YTD Global Rank",
sum(a."Overall Score") "YTD Global Total Score"
/*a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Inbound AHT",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Off"*/
from(
select 
a."MONTH",
a."UCID",
a."FUSION_ID",
a."ASM_NAME",
a."MANAGER",
a."LOCATION",
a."DEPT",
rank() OVER (PARTITION by a."MONTH",a."DEPT" ORDER BY (round( coalesce(a."Res Credit Points",0) + coalesce(a."AHT Points",0) + coalesce(a."CMS Usage Points",0)+ coalesce(a."TL Call Monitoring Points",0) +
coalesce(a."Collection call Model Points",0)
,2)) desc,a."MONTH",a."DEPT" ) "Overall Rank",
(round( coalesce(a."Res Credit Points",0) + coalesce(a."AHT Points",0) + coalesce(a."CMS Usage Points",0)+ coalesce(a."TL Call Monitoring Points",0) +
coalesce(a."Collection call Model Points",0)
,2))"Overall Score",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Inbound AHT",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Off"
from (
select 
a.month,c.ucid,a."TL FUSION_ID" "FUSION_ID",c.name "ASM_NAME",c.team_leader "MANAGER",c.location,c.dept,
round(avg(a."Resolution Credits"),2) "Resolution Credits",
rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept ) "Res Credit Rank",
case when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept ) =1 
then 7.5
when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )=2
then 5
else 2.5 end as "Res Credit Points",
/*case when round(avg(a."Resolution Credits"),2) < 2 then 0 else
(case when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )
<=round(d."Out Off"*0.15,0) then 7.5
when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )
<=round(d."Out Off"*0.6,0) then 5 
when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )
<=round(d."Out Off"*0.85,0) then 2.5 
else 0 end )
end as  "Res Credit Points",*/
e.cph_target,
round(avg(a."Inbound AHT"),2) "Inbound AHT",

case when round(avg(a."Inbound AHT"),2) > 660 then 0
 when round(avg(a."Inbound AHT"),2) >=660 then 5-(5*0.80)
when round(avg(a."Inbound AHT"),2) >=630 then 5-(5*0.60)
when round(avg(a."Inbound AHT"),2) >=600 then 5-(5*0.40)
else 5-(5*0.20) end as "AHT Points",
e.ib_aht_target,
round(avg(a."Cms Defect %"),2) "Cms Defect %",
case when round(avg(a."Cms Defect %"),2) <0.5 then 18.75
when round(avg(a."Cms Defect %"),2) < 1.0 then 12.5
when round(avg(a."Cms Defect %"),2) <1.5 then 6.25
else 0
end as "CMS Usage Points",

e.cms_defect_target,
round(avg(a."TL Call Monitoring Defect"),2) "TL Call Monitoring Defect",
case when round(avg(a."TL Call Monitoring Defect"),2) =0 then 3.75
 when round(avg(a."TL Call Monitoring Defect"),2) <= 25 then 2.5 
  when round(avg(a."TL Call Monitoring Defect"),2) <=75  then 1.25
else 0
end as "TL Call Monitoring Points",
e.call_monitoring_defect_target,
round(avg(a."Collection call Model Defect"),2) "Collection call Model Defect",
case when round(avg(a."Collection call Model Defect"),2) < 1.5 then 7.5
when round(avg(a."Collection call Model Defect"),2) < 2.5 then 5
when round(avg(a."Collection call Model Defect"),2) < 3.5 then 2.5
else 0
end "Collection call Model Points",
e.collection_call_model_defect_target,
d."Out Off"
from (
select 
a."MONTH",
a."FUSION_ID",
a."UCID",
a."SUPV_NAME",a."TL FUSION_ID",
a."MANAGER_NAME",
a."LOCATION",
a."DEPT",
a."Overall Score",
a."Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from(
select 
a."MONTH",
a."FUSION_ID",
a."UCID",
a."NAME" "SUPV_NAME",a."TL FUSION_ID",
a."TEAM_LEADER" "MANAGER_NAME",
a."LOCATION",
a."DEPT",
round((a."Res Credit Points"+a."Stella Star Points"+a."Adherence Points"+a."AHT Points"+a."CMS Usage Points"
+a."TL Call Monitoring Points"+a."Collection call Model Points"),2)  "Overall Score",
rank() OVER (PARTITION by month ORDER BY round((a."Res Credit Points"+a."Stella Star Points"+a."Adherence Points"+a."AHT Points"+a."CMS Usage Points"
+a."TL Call Monitoring Points"+a."Collection call Model Points"),2) desc,month ) "Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from (
select 
--"EMPLOYEE ID"--,name,"Team Lead",location,dept
b.month,b.TL_FUSIONID "FUSION_ID",
c.ucid
,b."Team Lead" NAME,c.TL_FUSIONID "TL FUSION_ID", c.team_leader,c.location,c.dept
,round(avg(b."Credit Per Hr"),3) "Resolution Credits"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept ) "Res Credit Rank"
,case when round(avg(b."Credit Per Hr"),3) >2.000 then 
(case when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.15,0) then 11.25 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.6,0) then 7.5 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.85,0) then 3.75 
else 0 end )
else 0
end as "Res Credit Points"
,i.cph_target
--,round(avg(b."Quality Score"),2) "Quality Score"
--,i.QUALITY_TARGET
,round(avg(b."Stella Star Rating"),2) "Stella Star Rating"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Stella Star Rating"),2) desc,b.month,c.dept ) "Stella Star Rank"
, case when round(avg(b."Stella Star Rating"),2) >4.6 then  5-(5*0.20)
when round(avg(b."Stella Star Rating"),2) >=4.5 then  5-(5*0.40)
when round(avg(b."Stella Star Rating"),2) >=4.4 then  5-(5*0.60)
when round(avg(b."Stella Star Rating"),2) >=4.3 then  5-(5*0.80)
else 0 
end as "Stella Star Points"
,i.STAR_TARGET
,round(avg(b."Schedule Adherence"),2) "Schedule Adherence"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Schedule Adherence"),2) desc,b.month,c.dept ) "Adherence Rank"
, case when round(avg(b."Schedule Adherence"),3)>92.50 then 5-(5*0.20)
when round(avg(b."Schedule Adherence"),3)>=90.00 then 5-(5*0.40)
when round(avg(b."Schedule Adherence"),3)>=87.50 then 5-(5*0.60)
when round(avg(b."Schedule Adherence"),3)>=85.00 then 5-(5*0.80)
else 0 end as "Adherence Points"
,i.ADHERENCE_TARGET
,round(avg(b."Inbound AHT"),2) "Inbound AHT"
--,coalesce (j."Inbound AHT",0) "Inbound AHT"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Inbound AHT"),2) desc,b.month,c.dept ) "AHT Rank"
,case when round(avg(b."Inbound AHT"),2)>660 then 0
 when round(avg(b."Inbound AHT"),2) >=660 then 5-(5*0.80)
when round(avg(b."Inbound AHT"),2) >=630 then 5-(5*0.60)
when round(avg(b."Inbound AHT"),2) >=600 then 5-(5*0.40)
else 5-(5*0.20) end as "AHT Points"
,i.ib_aht_target
,round(avg(b."Cms Defect %"),2) "Cms Defect %"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Cms Defect %"),2) asc,b.month,c.dept ) "Cms Defect Rank"
,case when round(avg(b."Cms Defect %"),2) <0.5 then 18.75
when round(avg(b."Cms Defect %"),2) < 1.0 then 12.5
when round(avg(b."Cms Defect %"),2) <1.5 then 6.25
else 0
end as "CMS Usage Points"
,i.CMS_DEFECT_TARGET
,f.qc_per "TL Call Monitoring Defect"
,case when f.qc_per = 0 then  7.5
when f.qc_per <= 25 then  5
when f.qc_per <= 75 then  2.5
else 0
end as  "TL Call Monitoring Points"
,i.call_monitoring_defect_target
,e.defect_per "Collection call Model Defect"
,case when e.defect_per < 1.5 then 7.5
when e.defect_per < 2.5 then 5
when e.defect_per < 3.5 then 2.5
else 0
end as "Collection call Model Points"
,i.collection_call_model_defect_target
,k."Out Of"
from
(
select 
a.month  ,a.ucid,a."EMPLOYEE ID",a.name,a.TL_FUSIONID,a."Team Lead",a.location,a.dept
,rank() OVER (PARTITION by a.month,a.dept ORDER BY
(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") desc,a.dept,a.month ) "Global Rank"
,(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") "Total Points"
,coalesce(a."Credit Per Hr",0) "Credit Per Hr" ,a."Credit Rank",a."Credits Score",a.CPH_TARGET
, coalesce (a."Quality Score",0)  "Quality Score"
,case when a."Quality Rank" is null then 1 else a."Quality Rank" end as "Quality Rank"
,coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0) as "Quality_Score",a.QUALITY_TARGET
,coalesce(a."Stella Star Rating",0) "Stella Star Rating"
,case when a."Stella Star Rank" is null then 1 else a."Stella Star Rank" end as "Stella Star Rank"
,coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0) as "Stella Star Score",a.STAR_TARGET
,coalesce(a."Schedule Adherence",0) "Schedule Adherence",a."Adherence Rank",a."Adherence Score",a.ADHERENCE_TARGET
,coalesce(a."Inbound AHT",0) "Inbound AHT",a."AHT Rank",a."AHT Score",a.IB_AHT_TARGET
,coalesce(a."Cms Defect %",0) "Cms Defect %" ,a."Cms Defect Rank",a."Cms Defect Score",a.CMS_DEFECT_TARGET
,a."Out Of"
from
(
select 
last_day(a.month) month,
a.ucid,
a.fusionid "EMPLOYEE ID",
a.name,
a.TL_FUSIONID,
a.team_leader "Team Lead",
a.location,
a.dept
--,rank() OVER (PARTITION by last_day(a.month),a.dept ORDER BY (coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0)) desc,a.dept,last_day(a.month) ) "Global Rank"
--,(coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0))  "Total Points"
,b."Credit Per Hr",b."Credit Rank",b."Credits Score",
--b.CPH_TARGET
i.CPH_TARGET
,c."Quality Score",c."Quality Rank",c."Quality_Score"
,i.QUALITY_TARGET
,d."Stella Star Rating",d."Stella Star Rank",d."Stella Star Score"
,i.STAR_TARGET
,e."Schedule Adherence",e."Adherence Rank",e."Adherence Score"
,i.ADHERENCE_TARGET
,f."Inbound AHT",f."AHT Rank",f."AHT Score"
,i.IB_AHT_TARGET
,g."Cms Defect %",g."Cms Defect Rank",g."Cms Defect Score"
,i.CMS_DEFECT_TARGET
,h."Out Of"
from asit_roster_table a
left join(
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
--,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
,"CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
,e."CPH_TARGET"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
left join(
select month,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95","CPH_TARGET"
from (
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of"
)a )b
where "CPH_TARGET" is not null)e on last_day(a.rpt_month)=last_day(e.month) and c.dept=e.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of",e."CPH_TARGET"
)a
) b on last_day(a.month)=last_day(b.month) and a.fusionid=b.fusionid
left join(
select last_day(roster_month) month,
a.fusion_id,c.ucid,a.employee_name,c.dept
,coalesce(round(avg(score),2),0) "Quality Score"
,rank() OVER (PARTITION by last_day(roster_month),c.dept ORDER BY coalesce(round(avg(score),2),0) desc,c.dept,last_day(roster_month) )  "Quality Rank"
,b."Out Of"
,case 
when coalesce(round(avg(score),2),0) >=97.50  then 3.75 
when coalesce(round(avg(score),2),0) >=95.20  then 2.5
when coalesce(round(avg(score),2),0) >=90  then 1.25 
else 0
end as
"Quality_Score"
from asit_quality a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.roster_month)=c.month and a.fusion_id=c.fusionid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.roster_month)=b.monthn and b.dept=c.dept
--where a.roster_month=last_day('31-JAN-24') 
--and a.ucid in (select distinct ucid from asit_roster_table where fusionid='105554' ) 
group by last_day(roster_month),a.fusion_id,c.ucid,a.employee_name,c.dept,b."Out Of"

)c on last_day(a.month)=last_day(c.month) and a.fusionid=c.fusion_id
left join(
select 
last_day(a.month) month,a.employee_custom_id,c.dept
--,a.team_leader
,coalesce(round(avg(star_rating),2),0) "Stella Star Rating"
,rank() OVER (PARTITION by last_day(a.month),c.dept  ORDER BY coalesce(round(avg(star_rating),2),0) desc,c.dept ,last_day(a.month) ) "Stella Star Rank"
,b."Out Of"
,case when coalesce(round(avg(star_rating),2),0) >= 4.6 then 4.00
when coalesce(round(avg(star_rating),2),0) >= 4.5 then 3.00 
when coalesce(round(avg(star_rating),2),0) >= 4.4 then 2.00
when coalesce(round(avg(star_rating),2),0) >= 4.3 then 1.00
else 0
end as "Stella Star Score"
from asit_star_rating a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.employee_custom_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
--where  a.month=last_day(a.month)
--and employee_custom_id in ('196400') 
group by last_day(a.month),c.dept,a.employee_custom_id,b."Out Of"
)d on last_day(a.month)=last_day(d.month) and a.fusionid=d.employee_custom_id
left join (
select 
last_day(a.month) month,a.fusion_id,c.dept 
,coalesce(round(adherence_percentage*100,2),0) "Schedule Adherence"
,rank() OVER (PARTITION by last_day(a.month),c.dept ORDER BY coalesce(round(adherence_percentage*100,2),0) desc,c.dept ,last_day(a.month) ) "Adherence Rank"
,b."Out Of"
,case when coalesce(round(adherence_percentage*100,2),0) >=95 then 4.00 
when coalesce(round(adherence_percentage*100,2),0) >=92.5 then 3.00
when coalesce(round(adherence_percentage*100,2),0) >=90 then 2.00 
when coalesce(round(adherence_percentage*100,2),0) >=87.5 then 1.00
else 0
end as
"Adherence Score"
from asit_telephony a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.fusion_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)e on last_day(a.month)=last_day(e.month) and a.fusionid=e.fusion_id
left join (
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
)f on to_char(last_day(a.month),'MON-YY')=f.month and a.fusionid=f.fusionid
left join(
select 
last_day(a.month) month,c.fusionid,a.ucid,c.dept,a.cms_defect_percentage,coalesce(round(a.cms_defect_percentage*100,2),0) "Cms Defect %"
,rank() OVER (PARTITION by a.month ORDER BY coalesce(round(a.cms_defect_percentage*100,2),0) asc,a.month ) "Cms Defect Rank"
,b."Out Of"
,case when coalesce(round(a.cms_defect_percentage*100,2),0) <0.5 then 18.5 
when coalesce(round(a.cms_defect_percentage*100,2),0) <1 then 12.5
when coalesce(round(a.cms_defect_percentage*100,2),0) <=1.5 then 6.25
else 0
end as
"Cms Defect Score"
from asit_cms_defect a
join(
select month,fusionid,ucid,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.ucid=c.ucid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)g on last_day(a.month)=g.month and a.fusionid=g.fusionid
left join(
select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)h on last_day(a.month)=h.monthn and a.dept=h.dept
left join CR_SC_AGNTS_TARGET i on last_day(a.month)=i.month and a.dept=i.dept
where --a.month>=last_day(sysdate)and
 a.dept in ('CCC-R','CCC-R SPANISH','FLEX')
and a.location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and a.designation in ('Agent')
and a.final_status='ACTIVE'
and a.team_leader not in (select name from not_teamleader)
)a)b
join(
select month,fusionid,ucid,name,TL_FUSIONID,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on b.month=c.month and b.TL_FUSIONID=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)d on b.month=d.monthn and c.dept=d.dept
left join (
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end defect_per 
 from asit_tl_impact
)e on b.month=e.month and b.TL_FUSIONID=e.fusionid
left join(
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end QC_per 
 from asit_tl_qc
)f on b.month=f.month and b.TL_FUSIONID=f.fusionid
left join CR_SC_TL_TARGET i on b.month=i.month and c.dept=i.dept
left join(
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
) j on to_char(b.month,'MON-YY')=j.month and b.TL_FUSIONID=j.fusionid
left join (select 
to_char(last_day(month),'MON-YY') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-YY'),dept
)k on to_char(b.month,'MON-YY')=k.monthn and c.dept=k.dept
--where  "EMPLOYEE ID" in('197233')
group by b.month,b.TL_FUSIONID,b."Team Lead"
,c.fusionid,c.ucid,c.TL_FUSIONID ,c.team_leader,c.location,c.dept,
i.cph_target,i.STAR_TARGET,i.ADHERENCE_TARGET,i.CMS_DEFECT_TARGET,i.collection_call_model_defect_target,i.call_monitoring_defect_target,i.ib_aht_target
,e.defect_per,f.QC_per,j."Inbound AHT",k."Out Of"
)a )a ) a 
join(
select month,fusionid,ucid,name,TL_FUSIONID,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Assistant Manager')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a."TL FUSION_ID"=c.fusionid
join(
select month,dept,count(fusionid) "Out Off" from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Assistant Manager')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by  month,dept
)d on a.month=d.month
left join CR_SC_AM_TARGET e on a.month=e.month and c.dept=e.dept
--where a.month>=last_day('01-JAN_24')
--where a."FUSION_ID" in ('195869')
group by a.month,a."TL FUSION_ID",a."MANAGER_NAME",c.ucid,c.name,c.team_leader,c.location,c.dept,d."Out Off"
,e.cph_target,e.ib_aht_target,e.cms_defect_target,e.call_monitoring_defect_target,e.collection_call_model_defect_target
)a ) a 
group by a."FUSION_ID"
)b on a."FUSION_ID"=b."FUSION_ID"
--where a."MONTH" >= last_day('01-FEB-24') and a."FUSION_ID"='100713'
order by a.month asc,a."Overall Rank";

   elsif (vfusionid5 is null) then
            OPEN p_result FOR
            
  select 
to_char(a."MONTH",'MON-YY') MONTH,
a."UCID",
a."FUSION_ID",
a."ASM_NAME",
a."MANAGER",
a."LOCATION",
a."DEPT",
a."Overall Rank",
a."Overall Score",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Inbound AHT",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Off",
b."YTD Global Rank",
b."YTD Global Total Score"
from(
select 
a."MONTH",
a."UCID",
a."FUSION_ID",
a."ASM_NAME",
a."MANAGER",
a."LOCATION",
a."DEPT",
rank() OVER (PARTITION by a."MONTH",a."DEPT" ORDER BY (round( coalesce(a."Res Credit Points",0) + coalesce(a."AHT Points",0) + coalesce(a."CMS Usage Points",0)+ coalesce(a."TL Call Monitoring Points",0) +
coalesce(a."Collection call Model Points",0)
,2)) desc,a."MONTH",a."DEPT" ) "Overall Rank",
(round( coalesce(a."Res Credit Points",0) + coalesce(a."AHT Points",0) + coalesce(a."CMS Usage Points",0)+ coalesce(a."TL Call Monitoring Points",0) +
coalesce(a."Collection call Model Points",0)
,2))"Overall Score",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Inbound AHT",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Off"
from (
select 
a.month,c.ucid,a."TL FUSION_ID" "FUSION_ID",c.name "ASM_NAME",c.team_leader "MANAGER",c.location,c.dept,
round(avg(a."Resolution Credits"),2) "Resolution Credits",
rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept ) "Res Credit Rank",
case when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept ) =1 
then 7.5
when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )=2
then 5
else 2.5 end as "Res Credit Points",
/*case when round(avg(a."Resolution Credits"),2) < 2 then 0 else
(case when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )
<=round(d."Out Off"*0.15,0) then 7.5
when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )
<=round(d."Out Off"*0.6,0) then 5 
when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )
<=round(d."Out Off"*0.85,0) then 2.5 
else 0 end )
end as  "Res Credit Points",*/
e.cph_target,
round(avg(a."Inbound AHT"),2) "Inbound AHT",

case when round(avg(a."Inbound AHT"),2) > 660 then 0
 when round(avg(a."Inbound AHT"),2) >=660 then 5-(5*0.80)
when round(avg(a."Inbound AHT"),2) >=630 then 5-(5*0.60)
when round(avg(a."Inbound AHT"),2) >=600 then 5-(5*0.40)
else 5-(5*0.20) end as "AHT Points",
e.ib_aht_target,
round(avg(a."Cms Defect %"),2) "Cms Defect %",
case when round(avg(a."Cms Defect %"),2) <0.5 then 18.75
when round(avg(a."Cms Defect %"),2) < 1.0 then 12.5
when round(avg(a."Cms Defect %"),2) <1.5 then 6.25
else 0
end as "CMS Usage Points",

e.cms_defect_target,
round(avg(a."TL Call Monitoring Defect"),2) "TL Call Monitoring Defect",
case when round(avg(a."TL Call Monitoring Defect"),2) =0 then 3.75
 when round(avg(a."TL Call Monitoring Defect"),2) <= 25 then 2.5 
  when round(avg(a."TL Call Monitoring Defect"),2) <=75  then 1.25
else 0
end as "TL Call Monitoring Points",
e.call_monitoring_defect_target,
round(avg(a."Collection call Model Defect"),2) "Collection call Model Defect",
case when round(avg(a."Collection call Model Defect"),2) < 1.5 then 7.5
when round(avg(a."Collection call Model Defect"),2) < 2.5 then 5
when round(avg(a."Collection call Model Defect"),2) < 3.5 then 2.5
else 0
end "Collection call Model Points",
e.collection_call_model_defect_target,
d."Out Off"
from (
select 
a."MONTH",
a."FUSION_ID",
a."UCID",
a."SUPV_NAME",a."TL FUSION_ID",
a."MANAGER_NAME",
a."LOCATION",
a."DEPT",
a."Overall Score",
a."Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from(
select 
a."MONTH",
a."FUSION_ID",
a."UCID",
a."NAME" "SUPV_NAME",a."TL FUSION_ID",
a."TEAM_LEADER" "MANAGER_NAME",
a."LOCATION",
a."DEPT",
round((a."Res Credit Points"+a."Stella Star Points"+a."Adherence Points"+a."AHT Points"+a."CMS Usage Points"
+a."TL Call Monitoring Points"+a."Collection call Model Points"),2)  "Overall Score",
rank() OVER (PARTITION by month ORDER BY round((a."Res Credit Points"+a."Stella Star Points"+a."Adherence Points"+a."AHT Points"+a."CMS Usage Points"
+a."TL Call Monitoring Points"+a."Collection call Model Points"),2) desc,month ) "Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from (
select 
--"EMPLOYEE ID"--,name,"Team Lead",location,dept
b.month,b.TL_FUSIONID "FUSION_ID",
c.ucid
,b."Team Lead" NAME,c.TL_FUSIONID "TL FUSION_ID", c.team_leader,c.location,c.dept
,round(avg(b."Credit Per Hr"),3) "Resolution Credits"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept ) "Res Credit Rank"
,case when round(avg(b."Credit Per Hr"),3) >2.000 then 
(case when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.15,0) then 11.25 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.6,0) then 7.5 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.85,0) then 3.75 
else 0 end )
else 0
end as "Res Credit Points"
,i.cph_target
--,round(avg(b."Quality Score"),2) "Quality Score"
--,i.QUALITY_TARGET
,round(avg(b."Stella Star Rating"),2) "Stella Star Rating"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Stella Star Rating"),2) desc,b.month,c.dept ) "Stella Star Rank"
, case when round(avg(b."Stella Star Rating"),2) >4.6 then  5-(5*0.20)
when round(avg(b."Stella Star Rating"),2) >=4.5 then  5-(5*0.40)
when round(avg(b."Stella Star Rating"),2) >=4.4 then  5-(5*0.60)
when round(avg(b."Stella Star Rating"),2) >=4.3 then  5-(5*0.80)
else 0 
end as "Stella Star Points"
,i.STAR_TARGET
,round(avg(b."Schedule Adherence"),2) "Schedule Adherence"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Schedule Adherence"),2) desc,b.month,c.dept ) "Adherence Rank"
, case when round(avg(b."Schedule Adherence"),3)>92.50 then 5-(5*0.20)
when round(avg(b."Schedule Adherence"),3)>=90.00 then 5-(5*0.40)
when round(avg(b."Schedule Adherence"),3)>=87.50 then 5-(5*0.60)
when round(avg(b."Schedule Adherence"),3)>=85.00 then 5-(5*0.80)
else 0 end as "Adherence Points"
,i.ADHERENCE_TARGET
,round(avg(b."Inbound AHT"),2) "Inbound AHT"
--,coalesce (j."Inbound AHT",0) "Inbound AHT"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Inbound AHT"),2) desc,b.month,c.dept ) "AHT Rank"
,case when round(avg(b."Inbound AHT"),2)>660 then 0
 when round(avg(b."Inbound AHT"),2) >=660 then 5-(5*0.80)
when round(avg(b."Inbound AHT"),2) >=630 then 5-(5*0.60)
when round(avg(b."Inbound AHT"),2) >=600 then 5-(5*0.40)
else 5-(5*0.20) end as "AHT Points"
,i.ib_aht_target
,round(avg(b."Cms Defect %"),2) "Cms Defect %"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Cms Defect %"),2) asc,b.month,c.dept ) "Cms Defect Rank"
,case when round(avg(b."Cms Defect %"),2) <0.5 then 18.75
when round(avg(b."Cms Defect %"),2) < 1.0 then 12.5
when round(avg(b."Cms Defect %"),2) <1.5 then 6.25
else 0
end as "CMS Usage Points"
,i.CMS_DEFECT_TARGET
,f.qc_per "TL Call Monitoring Defect"
,case when f.qc_per = 0 then  7.5
when f.qc_per <= 25 then  5
when f.qc_per <= 75 then  2.5
else 0
end as  "TL Call Monitoring Points"
,i.call_monitoring_defect_target
,e.defect_per "Collection call Model Defect"
,case when e.defect_per < 1.5 then 7.5
when e.defect_per < 2.5 then 5
when e.defect_per < 3.5 then 2.5
else 0
end as "Collection call Model Points"
,i.collection_call_model_defect_target
,k."Out Of"
from
(
select 
a.month  ,a.ucid,a."EMPLOYEE ID",a.name,a.TL_FUSIONID,a."Team Lead",a.location,a.dept
,rank() OVER (PARTITION by a.month,a.dept ORDER BY
(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") desc,a.dept,a.month ) "Global Rank"
,(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") "Total Points"
,coalesce(a."Credit Per Hr",0) "Credit Per Hr" ,a."Credit Rank",a."Credits Score",a.CPH_TARGET
, coalesce (a."Quality Score",0)  "Quality Score"
,case when a."Quality Rank" is null then 1 else a."Quality Rank" end as "Quality Rank"
,coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0) as "Quality_Score",a.QUALITY_TARGET
,coalesce(a."Stella Star Rating",0) "Stella Star Rating"
,case when a."Stella Star Rank" is null then 1 else a."Stella Star Rank" end as "Stella Star Rank"
,coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0) as "Stella Star Score",a.STAR_TARGET
,coalesce(a."Schedule Adherence",0) "Schedule Adherence",a."Adherence Rank",a."Adherence Score",a.ADHERENCE_TARGET
,coalesce(a."Inbound AHT",0) "Inbound AHT",a."AHT Rank",a."AHT Score",a.IB_AHT_TARGET
,coalesce(a."Cms Defect %",0) "Cms Defect %" ,a."Cms Defect Rank",a."Cms Defect Score",a.CMS_DEFECT_TARGET
,a."Out Of"
from
(
select 
last_day(a.month) month,
a.ucid,
a.fusionid "EMPLOYEE ID",
a.name,
a.TL_FUSIONID,
a.team_leader "Team Lead",
a.location,
a.dept
--,rank() OVER (PARTITION by last_day(a.month),a.dept ORDER BY (coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0)) desc,a.dept,last_day(a.month) ) "Global Rank"
--,(coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0))  "Total Points"
,b."Credit Per Hr",b."Credit Rank",b."Credits Score",
--b.CPH_TARGET
i.CPH_TARGET
,c."Quality Score",c."Quality Rank",c."Quality_Score"
,i.QUALITY_TARGET
,d."Stella Star Rating",d."Stella Star Rank",d."Stella Star Score"
,i.STAR_TARGET
,e."Schedule Adherence",e."Adherence Rank",e."Adherence Score"
,i.ADHERENCE_TARGET
,f."Inbound AHT",f."AHT Rank",f."AHT Score"
,i.IB_AHT_TARGET
,g."Cms Defect %",g."Cms Defect Rank",g."Cms Defect Score"
,i.CMS_DEFECT_TARGET
,h."Out Of"
from asit_roster_table a
left join(
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
--,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
,"CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
,e."CPH_TARGET"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
left join(
select month,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95","CPH_TARGET"
from (
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of"
)a )b
where "CPH_TARGET" is not null)e on last_day(a.rpt_month)=last_day(e.month) and c.dept=e.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of",e."CPH_TARGET"
)a
) b on last_day(a.month)=last_day(b.month) and a.fusionid=b.fusionid
left join(
select last_day(roster_month) month,
a.fusion_id,c.ucid,a.employee_name,c.dept
,coalesce(round(avg(score),2),0) "Quality Score"
,rank() OVER (PARTITION by last_day(roster_month),c.dept ORDER BY coalesce(round(avg(score),2),0) desc,c.dept,last_day(roster_month) )  "Quality Rank"
,b."Out Of"
,case 
when coalesce(round(avg(score),2),0) >=97.50  then 3.75 
when coalesce(round(avg(score),2),0) >=95.20  then 2.5
when coalesce(round(avg(score),2),0) >=90  then 1.25 
else 0
end as
"Quality_Score"
from asit_quality a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.roster_month)=c.month and a.fusion_id=c.fusionid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.roster_month)=b.monthn and b.dept=c.dept
--where a.roster_month=last_day('31-JAN-24') 
--and a.ucid in (select distinct ucid from asit_roster_table where fusionid='105554' ) 
group by last_day(roster_month),a.fusion_id,c.ucid,a.employee_name,c.dept,b."Out Of"

)c on last_day(a.month)=last_day(c.month) and a.fusionid=c.fusion_id
left join(
select 
last_day(a.month) month,a.employee_custom_id,c.dept
--,a.team_leader
,coalesce(round(avg(star_rating),2),0) "Stella Star Rating"
,rank() OVER (PARTITION by last_day(a.month),c.dept  ORDER BY coalesce(round(avg(star_rating),2),0) desc,c.dept ,last_day(a.month) ) "Stella Star Rank"
,b."Out Of"
,case when coalesce(round(avg(star_rating),2),0) >= 4.6 then 4.00
when coalesce(round(avg(star_rating),2),0) >= 4.5 then 3.00 
when coalesce(round(avg(star_rating),2),0) >= 4.4 then 2.00
when coalesce(round(avg(star_rating),2),0) >= 4.3 then 1.00
else 0
end as "Stella Star Score"
from asit_star_rating a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.employee_custom_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
--where  a.month=last_day(a.month)
--and employee_custom_id in ('196400') 
group by last_day(a.month),c.dept,a.employee_custom_id,b."Out Of"
)d on last_day(a.month)=last_day(d.month) and a.fusionid=d.employee_custom_id
left join (
select 
last_day(a.month) month,a.fusion_id,c.dept 
,coalesce(round(adherence_percentage*100,2),0) "Schedule Adherence"
,rank() OVER (PARTITION by last_day(a.month),c.dept ORDER BY coalesce(round(adherence_percentage*100,2),0) desc,c.dept ,last_day(a.month) ) "Adherence Rank"
,b."Out Of"
,case when coalesce(round(adherence_percentage*100,2),0) >=95 then 4.00 
when coalesce(round(adherence_percentage*100,2),0) >=92.5 then 3.00
when coalesce(round(adherence_percentage*100,2),0) >=90 then 2.00 
when coalesce(round(adherence_percentage*100,2),0) >=87.5 then 1.00
else 0
end as
"Adherence Score"
from asit_telephony a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.fusion_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)e on last_day(a.month)=last_day(e.month) and a.fusionid=e.fusion_id
left join (
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
)f on to_char(last_day(a.month),'MON-YY')=f.month and a.fusionid=f.fusionid
left join(
select 
last_day(a.month) month,c.fusionid,a.ucid,c.dept,a.cms_defect_percentage,coalesce(round(a.cms_defect_percentage*100,2),0) "Cms Defect %"
,rank() OVER (PARTITION by a.month ORDER BY coalesce(round(a.cms_defect_percentage*100,2),0) asc,a.month ) "Cms Defect Rank"
,b."Out Of"
,case when coalesce(round(a.cms_defect_percentage*100,2),0) <0.5 then 18.5 
when coalesce(round(a.cms_defect_percentage*100,2),0) <1 then 12.5
when coalesce(round(a.cms_defect_percentage*100,2),0) <=1.5 then 6.25
else 0
end as
"Cms Defect Score"
from asit_cms_defect a
join(
select month,fusionid,ucid,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.ucid=c.ucid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)g on last_day(a.month)=g.month and a.fusionid=g.fusionid
left join(
select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)h on last_day(a.month)=h.monthn and a.dept=h.dept
left join CR_SC_AGNTS_TARGET i on last_day(a.month)=i.month and a.dept=i.dept
where --a.month>=last_day(sysdate)and
 a.dept in ('CCC-R','CCC-R SPANISH','FLEX')
and a.location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and a.designation in ('Agent')
and a.final_status='ACTIVE'
and a.team_leader not in (select name from not_teamleader)
)a)b
join(
select month,fusionid,ucid,name,TL_FUSIONID,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on b.month=c.month and b.TL_FUSIONID=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)d on b.month=d.monthn and c.dept=d.dept
left join (
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end defect_per 
 from asit_tl_impact
)e on b.month=e.month and b.TL_FUSIONID=e.fusionid
left join(
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end QC_per 
 from asit_tl_qc
)f on b.month=f.month and b.TL_FUSIONID=f.fusionid
left join CR_SC_TL_TARGET i on b.month=i.month and c.dept=i.dept
left join(
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept

) j on to_char(b.month,'MON-YY')=j.month and b.TL_FUSIONID=j.fusionid
left join (select 
to_char(last_day(month),'MON-YY') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-YY'),dept
)k on to_char(b.month,'MON-YY')=k.monthn and c.dept=k.dept
--where  "EMPLOYEE ID" in('197233')
group by b.month,b.TL_FUSIONID,b."Team Lead"
,c.fusionid,c.ucid,c.TL_FUSIONID ,c.team_leader,c.location,c.dept,
i.cph_target,i.STAR_TARGET,i.ADHERENCE_TARGET,i.CMS_DEFECT_TARGET,i.collection_call_model_defect_target,i.call_monitoring_defect_target,i.ib_aht_target
,e.defect_per,f.QC_per,j."Inbound AHT",k."Out Of"
)a )a ) a 
join(
select month,fusionid,ucid,name,TL_FUSIONID,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Assistant Manager')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a."TL FUSION_ID"=c.fusionid
join(
select month,dept,count(fusionid) "Out Off" from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Assistant Manager')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by  month,dept
)d on a.month=d.month
left join CR_SC_AM_TARGET e on a.month=e.month and c.dept=e.dept
--where a.month>=last_day('01-JAN_24')
--where a."FUSION_ID" in ('195869')
group by a.month,a."TL FUSION_ID",a."MANAGER_NAME",c.ucid,c.name,c.team_leader,c.location,c.dept,d."Out Off"
,e.cph_target,e.ib_aht_target,e.cms_defect_target,e.call_monitoring_defect_target,e.collection_call_model_defect_target
)a ) a 
left join(
select 
/*a."MONTH",
a."UCID",*/
a."FUSION_ID",
/*a."ASM_NAME",
a."MANAGER",
a."LOCATION",
a."DEPT",*/
rank() OVER (order by sum(a."Overall Score") desc,a."FUSION_ID") "YTD Global Rank",
sum(a."Overall Score") "YTD Global Total Score"
/*a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Inbound AHT",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Off"*/
from(
select 
a."MONTH",
a."UCID",
a."FUSION_ID",
a."ASM_NAME",
a."MANAGER",
a."LOCATION",
a."DEPT",
rank() OVER (PARTITION by a."MONTH",a."DEPT" ORDER BY (round( coalesce(a."Res Credit Points",0) + coalesce(a."AHT Points",0) + coalesce(a."CMS Usage Points",0)+ coalesce(a."TL Call Monitoring Points",0) +
coalesce(a."Collection call Model Points",0)
,2)) desc,a."MONTH",a."DEPT" ) "Overall Rank",
(round( coalesce(a."Res Credit Points",0) + coalesce(a."AHT Points",0) + coalesce(a."CMS Usage Points",0)+ coalesce(a."TL Call Monitoring Points",0) +
coalesce(a."Collection call Model Points",0)
,2))"Overall Score",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Inbound AHT",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Off"
from (
select 
a.month,c.ucid,a."TL FUSION_ID" "FUSION_ID",c.name "ASM_NAME",c.team_leader "MANAGER",c.location,c.dept,
round(avg(a."Resolution Credits"),2) "Resolution Credits",
rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept ) "Res Credit Rank",
case when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept ) =1 
then 7.5
when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )=2
then 5
else 2.5 end as "Res Credit Points",
/*case when round(avg(a."Resolution Credits"),2) < 2 then 0 else
(case when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )
<=round(d."Out Off"*0.15,0) then 7.5
when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )
<=round(d."Out Off"*0.6,0) then 5 
when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )
<=round(d."Out Off"*0.85,0) then 2.5 
else 0 end )
end as  "Res Credit Points",*/
e.cph_target,
round(avg(a."Inbound AHT"),2) "Inbound AHT",

case when round(avg(a."Inbound AHT"),2) > 660 then 0
 when round(avg(a."Inbound AHT"),2) >=660 then 5-(5*0.80)
when round(avg(a."Inbound AHT"),2) >=630 then 5-(5*0.60)
when round(avg(a."Inbound AHT"),2) >=600 then 5-(5*0.40)
else 5-(5*0.20) end as "AHT Points",
e.ib_aht_target,
round(avg(a."Cms Defect %"),2) "Cms Defect %",
case when round(avg(a."Cms Defect %"),2) <0.5 then 18.75
when round(avg(a."Cms Defect %"),2) < 1.0 then 12.5
when round(avg(a."Cms Defect %"),2) <1.5 then 6.25
else 0
end as "CMS Usage Points",

e.cms_defect_target,
round(avg(a."TL Call Monitoring Defect"),2) "TL Call Monitoring Defect",
case when round(avg(a."TL Call Monitoring Defect"),2) =0 then 3.75
 when round(avg(a."TL Call Monitoring Defect"),2) <= 25 then 2.5 
  when round(avg(a."TL Call Monitoring Defect"),2) <=75  then 1.25
else 0
end as "TL Call Monitoring Points",
e.call_monitoring_defect_target,
round(avg(a."Collection call Model Defect"),2) "Collection call Model Defect",
case when round(avg(a."Collection call Model Defect"),2) < 1.5 then 7.5
when round(avg(a."Collection call Model Defect"),2) < 2.5 then 5
when round(avg(a."Collection call Model Defect"),2) < 3.5 then 2.5
else 0
end "Collection call Model Points",
e.collection_call_model_defect_target,
d."Out Off"
from (
select 
a."MONTH",
a."FUSION_ID",
a."UCID",
a."SUPV_NAME",a."TL FUSION_ID",
a."MANAGER_NAME",
a."LOCATION",
a."DEPT",
a."Overall Score",
a."Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from(
select 
a."MONTH",
a."FUSION_ID",
a."UCID",
a."NAME" "SUPV_NAME",a."TL FUSION_ID",
a."TEAM_LEADER" "MANAGER_NAME",
a."LOCATION",
a."DEPT",
round((a."Res Credit Points"+a."Stella Star Points"+a."Adherence Points"+a."AHT Points"+a."CMS Usage Points"
+a."TL Call Monitoring Points"+a."Collection call Model Points"),2)  "Overall Score",
rank() OVER (PARTITION by month ORDER BY round((a."Res Credit Points"+a."Stella Star Points"+a."Adherence Points"+a."AHT Points"+a."CMS Usage Points"
+a."TL Call Monitoring Points"+a."Collection call Model Points"),2) desc,month ) "Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from (
select 
--"EMPLOYEE ID"--,name,"Team Lead",location,dept
b.month,b.TL_FUSIONID "FUSION_ID",
c.ucid
,b."Team Lead" NAME,c.TL_FUSIONID "TL FUSION_ID", c.team_leader,c.location,c.dept
,round(avg(b."Credit Per Hr"),3) "Resolution Credits"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept ) "Res Credit Rank"
,case when round(avg(b."Credit Per Hr"),3) >2.000 then 
(case when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.15,0) then 11.25 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.6,0) then 7.5 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.85,0) then 3.75 
else 0 end )
else 0
end as "Res Credit Points"
,i.cph_target
--,round(avg(b."Quality Score"),2) "Quality Score"
--,i.QUALITY_TARGET
,round(avg(b."Stella Star Rating"),2) "Stella Star Rating"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Stella Star Rating"),2) desc,b.month,c.dept ) "Stella Star Rank"
, case when round(avg(b."Stella Star Rating"),2) >4.6 then  5-(5*0.20)
when round(avg(b."Stella Star Rating"),2) >=4.5 then  5-(5*0.40)
when round(avg(b."Stella Star Rating"),2) >=4.4 then  5-(5*0.60)
when round(avg(b."Stella Star Rating"),2) >=4.3 then  5-(5*0.80)
else 0 
end as "Stella Star Points"
,i.STAR_TARGET
,round(avg(b."Schedule Adherence"),2) "Schedule Adherence"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Schedule Adherence"),2) desc,b.month,c.dept ) "Adherence Rank"
, case when round(avg(b."Schedule Adherence"),3)>92.50 then 5-(5*0.20)
when round(avg(b."Schedule Adherence"),3)>=90.00 then 5-(5*0.40)
when round(avg(b."Schedule Adherence"),3)>=87.50 then 5-(5*0.60)
when round(avg(b."Schedule Adherence"),3)>=85.00 then 5-(5*0.80)
else 0 end as "Adherence Points"
,i.ADHERENCE_TARGET
,round(avg(b."Inbound AHT"),2) "Inbound AHT"
--,coalesce (j."Inbound AHT",0) "Inbound AHT"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Inbound AHT"),2) desc,b.month,c.dept ) "AHT Rank"
,case when round(avg(b."Inbound AHT"),2)>660 then 0
 when round(avg(b."Inbound AHT"),2) >=660 then 5-(5*0.80)
when round(avg(b."Inbound AHT"),2) >=630 then 5-(5*0.60)
when round(avg(b."Inbound AHT"),2) >=600 then 5-(5*0.40)
else 5-(5*0.20) end as "AHT Points"
,i.ib_aht_target
,round(avg(b."Cms Defect %"),2) "Cms Defect %"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Cms Defect %"),2) asc,b.month,c.dept ) "Cms Defect Rank"
,case when round(avg(b."Cms Defect %"),2) <0.5 then 18.75
when round(avg(b."Cms Defect %"),2) < 1.0 then 12.5
when round(avg(b."Cms Defect %"),2) <1.5 then 6.25
else 0
end as "CMS Usage Points"
,i.CMS_DEFECT_TARGET
,f.qc_per "TL Call Monitoring Defect"
,case when f.qc_per = 0 then  7.5
when f.qc_per <= 25 then  5
when f.qc_per <= 75 then  2.5
else 0
end as  "TL Call Monitoring Points"
,i.call_monitoring_defect_target
,e.defect_per "Collection call Model Defect"
,case when e.defect_per < 1.5 then 7.5
when e.defect_per < 2.5 then 5
when e.defect_per < 3.5 then 2.5
else 0
end as "Collection call Model Points"
,i.collection_call_model_defect_target
,k."Out Of"
from
(
select 
a.month  ,a.ucid,a."EMPLOYEE ID",a.name,a.TL_FUSIONID,a."Team Lead",a.location,a.dept
,rank() OVER (PARTITION by a.month,a.dept ORDER BY
(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") desc,a.dept,a.month ) "Global Rank"
,(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") "Total Points"
,coalesce(a."Credit Per Hr",0) "Credit Per Hr" ,a."Credit Rank",a."Credits Score",a.CPH_TARGET
, coalesce (a."Quality Score",0)  "Quality Score"
,case when a."Quality Rank" is null then 1 else a."Quality Rank" end as "Quality Rank"
,coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0) as "Quality_Score",a.QUALITY_TARGET
,coalesce(a."Stella Star Rating",0) "Stella Star Rating"
,case when a."Stella Star Rank" is null then 1 else a."Stella Star Rank" end as "Stella Star Rank"
,coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0) as "Stella Star Score",a.STAR_TARGET
,coalesce(a."Schedule Adherence",0) "Schedule Adherence",a."Adherence Rank",a."Adherence Score",a.ADHERENCE_TARGET
,coalesce(a."Inbound AHT",0) "Inbound AHT",a."AHT Rank",a."AHT Score",a.IB_AHT_TARGET
,coalesce(a."Cms Defect %",0) "Cms Defect %" ,a."Cms Defect Rank",a."Cms Defect Score",a.CMS_DEFECT_TARGET
,a."Out Of"
from
(
select 
last_day(a.month) month,
a.ucid,
a.fusionid "EMPLOYEE ID",
a.name,
a.TL_FUSIONID,
a.team_leader "Team Lead",
a.location,
a.dept
--,rank() OVER (PARTITION by last_day(a.month),a.dept ORDER BY (coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0)) desc,a.dept,last_day(a.month) ) "Global Rank"
--,(coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0))  "Total Points"
,b."Credit Per Hr",b."Credit Rank",b."Credits Score",
--b.CPH_TARGET
i.CPH_TARGET
,c."Quality Score",c."Quality Rank",c."Quality_Score"
,i.QUALITY_TARGET
,d."Stella Star Rating",d."Stella Star Rank",d."Stella Star Score"
,i.STAR_TARGET
,e."Schedule Adherence",e."Adherence Rank",e."Adherence Score"
,i.ADHERENCE_TARGET
,f."Inbound AHT",f."AHT Rank",f."AHT Score"
,i.IB_AHT_TARGET
,g."Cms Defect %",g."Cms Defect Rank",g."Cms Defect Score"
,i.CMS_DEFECT_TARGET
,h."Out Of"
from asit_roster_table a
left join(
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
--,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
,"CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
,e."CPH_TARGET"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
left join(
select month,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95","CPH_TARGET"
from (
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of"
)a )b
where "CPH_TARGET" is not null)e on last_day(a.rpt_month)=last_day(e.month) and c.dept=e.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of",e."CPH_TARGET"
)a
) b on last_day(a.month)=last_day(b.month) and a.fusionid=b.fusionid
left join(
select last_day(roster_month) month,
a.fusion_id,c.ucid,a.employee_name,c.dept
,coalesce(round(avg(score),2),0) "Quality Score"
,rank() OVER (PARTITION by last_day(roster_month),c.dept ORDER BY coalesce(round(avg(score),2),0) desc,c.dept,last_day(roster_month) )  "Quality Rank"
,b."Out Of"
,case 
when coalesce(round(avg(score),2),0) >=97.50  then 3.75 
when coalesce(round(avg(score),2),0) >=95.20  then 2.5
when coalesce(round(avg(score),2),0) >=90  then 1.25 
else 0
end as
"Quality_Score"
from asit_quality a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.roster_month)=c.month and a.fusion_id=c.fusionid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.roster_month)=b.monthn and b.dept=c.dept
--where a.roster_month=last_day('31-JAN-24') 
--and a.ucid in (select distinct ucid from asit_roster_table where fusionid='105554' ) 
group by last_day(roster_month),a.fusion_id,c.ucid,a.employee_name,c.dept,b."Out Of"

)c on last_day(a.month)=last_day(c.month) and a.fusionid=c.fusion_id
left join(
select 
last_day(a.month) month,a.employee_custom_id,c.dept
--,a.team_leader
,coalesce(round(avg(star_rating),2),0) "Stella Star Rating"
,rank() OVER (PARTITION by last_day(a.month),c.dept  ORDER BY coalesce(round(avg(star_rating),2),0) desc,c.dept ,last_day(a.month) ) "Stella Star Rank"
,b."Out Of"
,case when coalesce(round(avg(star_rating),2),0) >= 4.6 then 4.00
when coalesce(round(avg(star_rating),2),0) >= 4.5 then 3.00 
when coalesce(round(avg(star_rating),2),0) >= 4.4 then 2.00
when coalesce(round(avg(star_rating),2),0) >= 4.3 then 1.00
else 0
end as "Stella Star Score"
from asit_star_rating a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.employee_custom_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
--where  a.month=last_day(a.month)
--and employee_custom_id in ('196400') 
group by last_day(a.month),c.dept,a.employee_custom_id,b."Out Of"
)d on last_day(a.month)=last_day(d.month) and a.fusionid=d.employee_custom_id
left join (
select 
last_day(a.month) month,a.fusion_id,c.dept 
,coalesce(round(adherence_percentage*100,2),0) "Schedule Adherence"
,rank() OVER (PARTITION by last_day(a.month),c.dept ORDER BY coalesce(round(adherence_percentage*100,2),0) desc,c.dept ,last_day(a.month) ) "Adherence Rank"
,b."Out Of"
,case when coalesce(round(adherence_percentage*100,2),0) >=95 then 4.00 
when coalesce(round(adherence_percentage*100,2),0) >=92.5 then 3.00
when coalesce(round(adherence_percentage*100,2),0) >=90 then 2.00 
when coalesce(round(adherence_percentage*100,2),0) >=87.5 then 1.00
else 0
end as
"Adherence Score"
from asit_telephony a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.fusion_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)e on last_day(a.month)=last_day(e.month) and a.fusionid=e.fusion_id
left join (
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
)f on to_char(last_day(a.month),'MON-YY')=f.month and a.fusionid=f.fusionid
left join(
select 
last_day(a.month) month,c.fusionid,a.ucid,c.dept,a.cms_defect_percentage,coalesce(round(a.cms_defect_percentage*100,2),0) "Cms Defect %"
,rank() OVER (PARTITION by a.month ORDER BY coalesce(round(a.cms_defect_percentage*100,2),0) asc,a.month ) "Cms Defect Rank"
,b."Out Of"
,case when coalesce(round(a.cms_defect_percentage*100,2),0) <0.5 then 18.5 
when coalesce(round(a.cms_defect_percentage*100,2),0) <1 then 12.5
when coalesce(round(a.cms_defect_percentage*100,2),0) <=1.5 then 6.25
else 0
end as
"Cms Defect Score"
from asit_cms_defect a
join(
select month,fusionid,ucid,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.ucid=c.ucid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)g on last_day(a.month)=g.month and a.fusionid=g.fusionid
left join(
select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)h on last_day(a.month)=h.monthn and a.dept=h.dept
left join CR_SC_AGNTS_TARGET i on last_day(a.month)=i.month and a.dept=i.dept
where --a.month>=last_day(sysdate)and
 a.dept in ('CCC-R','CCC-R SPANISH','FLEX')
and a.location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and a.designation in ('Agent')
and a.final_status='ACTIVE'
and a.team_leader not in (select name from not_teamleader)
)a)b
join(
select month,fusionid,ucid,name,TL_FUSIONID,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on b.month=c.month and b.TL_FUSIONID=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)d on b.month=d.monthn and c.dept=d.dept
left join (
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end defect_per 
 from asit_tl_impact
)e on b.month=e.month and b.TL_FUSIONID=e.fusionid
left join(
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end QC_per 
 from asit_tl_qc
)f on b.month=f.month and b.TL_FUSIONID=f.fusionid
left join CR_SC_TL_TARGET i on b.month=i.month and c.dept=i.dept
left join(
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
) j on to_char(b.month,'MON-YY')=j.month and b.TL_FUSIONID=j.fusionid
left join (select 
to_char(last_day(month),'MON-YY') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-YY'),dept
)k on to_char(b.month,'MON-YY')=k.monthn and c.dept=k.dept
--where  "EMPLOYEE ID" in('197233')
group by b.month,b.TL_FUSIONID,b."Team Lead"
,c.fusionid,c.ucid,c.TL_FUSIONID ,c.team_leader,c.location,c.dept,
i.cph_target,i.STAR_TARGET,i.ADHERENCE_TARGET,i.CMS_DEFECT_TARGET,i.collection_call_model_defect_target,i.call_monitoring_defect_target,i.ib_aht_target
,e.defect_per,f.QC_per,j."Inbound AHT",k."Out Of"
)a )a ) a 
join(
select month,fusionid,ucid,name,TL_FUSIONID,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Assistant Manager')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a."TL FUSION_ID"=c.fusionid
join(
select month,dept,count(fusionid) "Out Off" from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Assistant Manager')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by  month,dept
)d on a.month=d.month
left join CR_SC_AM_TARGET e on a.month=e.month and c.dept=e.dept
--where a.month>=last_day('01-JAN_24')
--where a."FUSION_ID" in ('195869')
group by a.month,a."TL FUSION_ID",a."MANAGER_NAME",c.ucid,c.name,c.team_leader,c.location,c.dept,d."Out Off"
,e.cph_target,e.ib_aht_target,e.cms_defect_target,e.call_monitoring_defect_target,e.collection_call_model_defect_target
)a ) a 
group by a."FUSION_ID"
)b on a."FUSION_ID"=b."FUSION_ID"
where a."MONTH" >= last_day(period)
--and a."FUSION_ID"='100713'
order by a.month asc,a."Overall Rank";  


elsif (period is null) then
            OPEN p_result FOR
            
select 
to_char(a."MONTH",'MON-YY') MONTH,
a."UCID",
a."FUSION_ID",
a."ASM_NAME",
a."MANAGER",
a."LOCATION",
a."DEPT",
a."Overall Rank",
a."Overall Score",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Inbound AHT",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Off",
b."YTD Global Rank",
b."YTD Global Total Score"
from(
select 
a."MONTH",
a."UCID",
a."FUSION_ID",
a."ASM_NAME",
a."MANAGER",
a."LOCATION",
a."DEPT",
rank() OVER (PARTITION by a."MONTH",a."DEPT" ORDER BY (round( coalesce(a."Res Credit Points",0) + coalesce(a."AHT Points",0) + coalesce(a."CMS Usage Points",0)+ coalesce(a."TL Call Monitoring Points",0) +
coalesce(a."Collection call Model Points",0)
,2)) desc,a."MONTH",a."DEPT" ) "Overall Rank",
(round( coalesce(a."Res Credit Points",0) + coalesce(a."AHT Points",0) + coalesce(a."CMS Usage Points",0)+ coalesce(a."TL Call Monitoring Points",0) +
coalesce(a."Collection call Model Points",0)
,2))"Overall Score",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Inbound AHT",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Off"
from (
select 
a.month,c.ucid,a."TL FUSION_ID" "FUSION_ID",c.name "ASM_NAME",c.team_leader "MANAGER",c.location,c.dept,
round(avg(a."Resolution Credits"),2) "Resolution Credits",
rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept ) "Res Credit Rank",
case when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept ) =1 
then 7.5
when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )=2
then 5
else 2.5 end as "Res Credit Points",
/*case when round(avg(a."Resolution Credits"),2) < 2 then 0 else
(case when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )
<=round(d."Out Off"*0.15,0) then 7.5
when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )
<=round(d."Out Off"*0.6,0) then 5 
when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )
<=round(d."Out Off"*0.85,0) then 2.5 
else 0 end )
end as  "Res Credit Points",*/
e.cph_target,
round(avg(a."Inbound AHT"),2) "Inbound AHT",

case when round(avg(a."Inbound AHT"),2) > 660 then 0
 when round(avg(a."Inbound AHT"),2) >=660 then 5-(5*0.80)
when round(avg(a."Inbound AHT"),2) >=630 then 5-(5*0.60)
when round(avg(a."Inbound AHT"),2) >=600 then 5-(5*0.40)
else 5-(5*0.20) end as "AHT Points",
e.ib_aht_target,
round(avg(a."Cms Defect %"),2) "Cms Defect %",
case when round(avg(a."Cms Defect %"),2) <0.5 then 18.75
when round(avg(a."Cms Defect %"),2) < 1.0 then 12.5
when round(avg(a."Cms Defect %"),2) <1.5 then 6.25
else 0
end as "CMS Usage Points",

e.cms_defect_target,
round(avg(a."TL Call Monitoring Defect"),2) "TL Call Monitoring Defect",
case when round(avg(a."TL Call Monitoring Defect"),2) =0 then 3.75
 when round(avg(a."TL Call Monitoring Defect"),2) <= 25 then 2.5 
  when round(avg(a."TL Call Monitoring Defect"),2) <=75  then 1.25
else 0
end as "TL Call Monitoring Points",
e.call_monitoring_defect_target,
round(avg(a."Collection call Model Defect"),2) "Collection call Model Defect",
case when round(avg(a."Collection call Model Defect"),2) < 1.5 then 7.5
when round(avg(a."Collection call Model Defect"),2) < 2.5 then 5
when round(avg(a."Collection call Model Defect"),2) < 3.5 then 2.5
else 0
end "Collection call Model Points",
e.collection_call_model_defect_target,
d."Out Off"
from (
select 
a."MONTH",
a."FUSION_ID",
a."UCID",
a."SUPV_NAME",a."TL FUSION_ID",
a."MANAGER_NAME",
a."LOCATION",
a."DEPT",
a."Overall Score",
a."Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from(
select 
a."MONTH",
a."FUSION_ID",
a."UCID",
a."NAME" "SUPV_NAME",a."TL FUSION_ID",
a."TEAM_LEADER" "MANAGER_NAME",
a."LOCATION",
a."DEPT",
round((a."Res Credit Points"+a."Stella Star Points"+a."Adherence Points"+a."AHT Points"+a."CMS Usage Points"
+a."TL Call Monitoring Points"+a."Collection call Model Points"),2)  "Overall Score",
rank() OVER (PARTITION by month ORDER BY round((a."Res Credit Points"+a."Stella Star Points"+a."Adherence Points"+a."AHT Points"+a."CMS Usage Points"
+a."TL Call Monitoring Points"+a."Collection call Model Points"),2) desc,month ) "Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from (
select 
--"EMPLOYEE ID"--,name,"Team Lead",location,dept
b.month,b.TL_FUSIONID "FUSION_ID",
c.ucid
,b."Team Lead" NAME,c.TL_FUSIONID "TL FUSION_ID", c.team_leader,c.location,c.dept
,round(avg(b."Credit Per Hr"),3) "Resolution Credits"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept ) "Res Credit Rank"
,case when round(avg(b."Credit Per Hr"),3) >2.000 then 
(case when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.15,0) then 11.25 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.6,0) then 7.5 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.85,0) then 3.75 
else 0 end )
else 0
end as "Res Credit Points"
,i.cph_target
--,round(avg(b."Quality Score"),2) "Quality Score"
--,i.QUALITY_TARGET
,round(avg(b."Stella Star Rating"),2) "Stella Star Rating"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Stella Star Rating"),2) desc,b.month,c.dept ) "Stella Star Rank"
, case when round(avg(b."Stella Star Rating"),2) >4.6 then  5-(5*0.20)
when round(avg(b."Stella Star Rating"),2) >=4.5 then  5-(5*0.40)
when round(avg(b."Stella Star Rating"),2) >=4.4 then  5-(5*0.60)
when round(avg(b."Stella Star Rating"),2) >=4.3 then  5-(5*0.80)
else 0 
end as "Stella Star Points"
,i.STAR_TARGET
,round(avg(b."Schedule Adherence"),2) "Schedule Adherence"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Schedule Adherence"),2) desc,b.month,c.dept ) "Adherence Rank"
, case when round(avg(b."Schedule Adherence"),3)>92.50 then 5-(5*0.20)
when round(avg(b."Schedule Adherence"),3)>=90.00 then 5-(5*0.40)
when round(avg(b."Schedule Adherence"),3)>=87.50 then 5-(5*0.60)
when round(avg(b."Schedule Adherence"),3)>=85.00 then 5-(5*0.80)
else 0 end as "Adherence Points"
,i.ADHERENCE_TARGET
,round(avg(b."Inbound AHT"),2) "Inbound AHT"
--,coalesce (j."Inbound AHT",0) "Inbound AHT"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Inbound AHT"),2) desc,b.month,c.dept ) "AHT Rank"
,case when round(avg(b."Inbound AHT"),2)>660 then 0
 when round(avg(b."Inbound AHT"),2) >=660 then 5-(5*0.80)
when round(avg(b."Inbound AHT"),2) >=630 then 5-(5*0.60)
when round(avg(b."Inbound AHT"),2) >=600 then 5-(5*0.40)
else 5-(5*0.20) end as "AHT Points"
,i.ib_aht_target
,round(avg(b."Cms Defect %"),2) "Cms Defect %"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Cms Defect %"),2) asc,b.month,c.dept ) "Cms Defect Rank"
,case when round(avg(b."Cms Defect %"),2) <0.5 then 18.75
when round(avg(b."Cms Defect %"),2) < 1.0 then 12.5
when round(avg(b."Cms Defect %"),2) <1.5 then 6.25
else 0
end as "CMS Usage Points"
,i.CMS_DEFECT_TARGET
,f.qc_per "TL Call Monitoring Defect"
,case when f.qc_per = 0 then  7.5
when f.qc_per <= 25 then  5
when f.qc_per <= 75 then  2.5
else 0
end as  "TL Call Monitoring Points"
,i.call_monitoring_defect_target
,e.defect_per "Collection call Model Defect"
,case when e.defect_per < 1.5 then 7.5
when e.defect_per < 2.5 then 5
when e.defect_per < 3.5 then 2.5
else 0
end as "Collection call Model Points"
,i.collection_call_model_defect_target
,k."Out Of"
from
(
select 
a.month  ,a.ucid,a."EMPLOYEE ID",a.name,a.TL_FUSIONID,a."Team Lead",a.location,a.dept
,rank() OVER (PARTITION by a.month,a.dept ORDER BY
(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") desc,a.dept,a.month ) "Global Rank"
,(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") "Total Points"
,coalesce(a."Credit Per Hr",0) "Credit Per Hr" ,a."Credit Rank",a."Credits Score",a.CPH_TARGET
, coalesce (a."Quality Score",0)  "Quality Score"
,case when a."Quality Rank" is null then 1 else a."Quality Rank" end as "Quality Rank"
,coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0) as "Quality_Score",a.QUALITY_TARGET
,coalesce(a."Stella Star Rating",0) "Stella Star Rating"
,case when a."Stella Star Rank" is null then 1 else a."Stella Star Rank" end as "Stella Star Rank"
,coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0) as "Stella Star Score",a.STAR_TARGET
,coalesce(a."Schedule Adherence",0) "Schedule Adherence",a."Adherence Rank",a."Adherence Score",a.ADHERENCE_TARGET
,coalesce(a."Inbound AHT",0) "Inbound AHT",a."AHT Rank",a."AHT Score",a.IB_AHT_TARGET
,coalesce(a."Cms Defect %",0) "Cms Defect %" ,a."Cms Defect Rank",a."Cms Defect Score",a.CMS_DEFECT_TARGET
,a."Out Of"
from
(
select 
last_day(a.month) month,
a.ucid,
a.fusionid "EMPLOYEE ID",
a.name,
a.TL_FUSIONID,
a.team_leader "Team Lead",
a.location,
a.dept
--,rank() OVER (PARTITION by last_day(a.month),a.dept ORDER BY (coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0)) desc,a.dept,last_day(a.month) ) "Global Rank"
--,(coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0))  "Total Points"
,b."Credit Per Hr",b."Credit Rank",b."Credits Score",
--b.CPH_TARGET
i.CPH_TARGET
,c."Quality Score",c."Quality Rank",c."Quality_Score"
,i.QUALITY_TARGET
,d."Stella Star Rating",d."Stella Star Rank",d."Stella Star Score"
,i.STAR_TARGET
,e."Schedule Adherence",e."Adherence Rank",e."Adherence Score"
,i.ADHERENCE_TARGET
,f."Inbound AHT",f."AHT Rank",f."AHT Score"
,i.IB_AHT_TARGET
,g."Cms Defect %",g."Cms Defect Rank",g."Cms Defect Score"
,i.CMS_DEFECT_TARGET
,h."Out Of"
from asit_roster_table a
left join(
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
--,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
,"CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
,e."CPH_TARGET"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
left join(
select month,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95","CPH_TARGET"
from (
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of"
)a )b
where "CPH_TARGET" is not null)e on last_day(a.rpt_month)=last_day(e.month) and c.dept=e.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of",e."CPH_TARGET"
)a
) b on last_day(a.month)=last_day(b.month) and a.fusionid=b.fusionid
left join(
select last_day(roster_month) month,
a.fusion_id,c.ucid,a.employee_name,c.dept
,coalesce(round(avg(score),2),0) "Quality Score"
,rank() OVER (PARTITION by last_day(roster_month),c.dept ORDER BY coalesce(round(avg(score),2),0) desc,c.dept,last_day(roster_month) )  "Quality Rank"
,b."Out Of"
,case 
when coalesce(round(avg(score),2),0) >=97.50  then 3.75 
when coalesce(round(avg(score),2),0) >=95.20  then 2.5
when coalesce(round(avg(score),2),0) >=90  then 1.25 
else 0
end as
"Quality_Score"
from asit_quality a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.roster_month)=c.month and a.fusion_id=c.fusionid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.roster_month)=b.monthn and b.dept=c.dept
--where a.roster_month=last_day('31-JAN-24') 
--and a.ucid in (select distinct ucid from asit_roster_table where fusionid='105554' ) 
group by last_day(roster_month),a.fusion_id,c.ucid,a.employee_name,c.dept,b."Out Of"

)c on last_day(a.month)=last_day(c.month) and a.fusionid=c.fusion_id
left join(
select 
last_day(a.month) month,a.employee_custom_id,c.dept
--,a.team_leader
,coalesce(round(avg(star_rating),2),0) "Stella Star Rating"
,rank() OVER (PARTITION by last_day(a.month),c.dept  ORDER BY coalesce(round(avg(star_rating),2),0) desc,c.dept ,last_day(a.month) ) "Stella Star Rank"
,b."Out Of"
,case when coalesce(round(avg(star_rating),2),0) >= 4.6 then 4.00
when coalesce(round(avg(star_rating),2),0) >= 4.5 then 3.00 
when coalesce(round(avg(star_rating),2),0) >= 4.4 then 2.00
when coalesce(round(avg(star_rating),2),0) >= 4.3 then 1.00
else 0
end as "Stella Star Score"
from asit_star_rating a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.employee_custom_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
--where  a.month=last_day(a.month)
--and employee_custom_id in ('196400') 
group by last_day(a.month),c.dept,a.employee_custom_id,b."Out Of"
)d on last_day(a.month)=last_day(d.month) and a.fusionid=d.employee_custom_id
left join (
select 
last_day(a.month) month,a.fusion_id,c.dept 
,coalesce(round(adherence_percentage*100,2),0) "Schedule Adherence"
,rank() OVER (PARTITION by last_day(a.month),c.dept ORDER BY coalesce(round(adherence_percentage*100,2),0) desc,c.dept ,last_day(a.month) ) "Adherence Rank"
,b."Out Of"
,case when coalesce(round(adherence_percentage*100,2),0) >=95 then 4.00 
when coalesce(round(adherence_percentage*100,2),0) >=92.5 then 3.00
when coalesce(round(adherence_percentage*100,2),0) >=90 then 2.00 
when coalesce(round(adherence_percentage*100,2),0) >=87.5 then 1.00
else 0
end as
"Adherence Score"
from asit_telephony a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.fusion_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)e on last_day(a.month)=last_day(e.month) and a.fusionid=e.fusion_id
left join (
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
)f on to_char(last_day(a.month),'MON-YY')=f.month and a.fusionid=f.fusionid
left join(
select 
last_day(a.month) month,c.fusionid,a.ucid,c.dept,a.cms_defect_percentage,coalesce(round(a.cms_defect_percentage*100,2),0) "Cms Defect %"
,rank() OVER (PARTITION by a.month ORDER BY coalesce(round(a.cms_defect_percentage*100,2),0) asc,a.month ) "Cms Defect Rank"
,b."Out Of"
,case when coalesce(round(a.cms_defect_percentage*100,2),0) <0.5 then 18.5 
when coalesce(round(a.cms_defect_percentage*100,2),0) <1 then 12.5
when coalesce(round(a.cms_defect_percentage*100,2),0) <=1.5 then 6.25
else 0
end as
"Cms Defect Score"
from asit_cms_defect a
join(
select month,fusionid,ucid,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.ucid=c.ucid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)g on last_day(a.month)=g.month and a.fusionid=g.fusionid
left join(
select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)h on last_day(a.month)=h.monthn and a.dept=h.dept
left join CR_SC_AGNTS_TARGET i on last_day(a.month)=i.month and a.dept=i.dept
where --a.month>=last_day(sysdate)and
 a.dept in ('CCC-R','CCC-R SPANISH','FLEX')
and a.location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and a.designation in ('Agent')
and a.final_status='ACTIVE'
and a.team_leader not in (select name from not_teamleader)
)a)b
join(
select month,fusionid,ucid,name,TL_FUSIONID,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on b.month=c.month and b.TL_FUSIONID=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)d on b.month=d.monthn and c.dept=d.dept
left join (
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end defect_per 
 from asit_tl_impact
)e on b.month=e.month and b.TL_FUSIONID=e.fusionid
left join(
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end QC_per 
 from asit_tl_qc
)f on b.month=f.month and b.TL_FUSIONID=f.fusionid
left join CR_SC_TL_TARGET i on b.month=i.month and c.dept=i.dept
left join(
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept

) j on to_char(b.month,'MON-YY')=j.month and b.TL_FUSIONID=j.fusionid
left join (select 
to_char(last_day(month),'MON-YY') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-YY'),dept
)k on to_char(b.month,'MON-YY')=k.monthn and c.dept=k.dept
--where  "EMPLOYEE ID" in('197233')
group by b.month,b.TL_FUSIONID,b."Team Lead"
,c.fusionid,c.ucid,c.TL_FUSIONID ,c.team_leader,c.location,c.dept,
i.cph_target,i.STAR_TARGET,i.ADHERENCE_TARGET,i.CMS_DEFECT_TARGET,i.collection_call_model_defect_target,i.call_monitoring_defect_target,i.ib_aht_target
,e.defect_per,f.QC_per,j."Inbound AHT",k."Out Of"
)a )a ) a 
join(
select month,fusionid,ucid,name,TL_FUSIONID,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Assistant Manager')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a."TL FUSION_ID"=c.fusionid
join(
select month,dept,count(fusionid) "Out Off" from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Assistant Manager')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by  month,dept
)d on a.month=d.month
left join CR_SC_AM_TARGET e on a.month=e.month and c.dept=e.dept
--where a.month>=last_day('01-JAN_24')
--where a."FUSION_ID" in ('195869')
group by a.month,a."TL FUSION_ID",a."MANAGER_NAME",c.ucid,c.name,c.team_leader,c.location,c.dept,d."Out Off"
,e.cph_target,e.ib_aht_target,e.cms_defect_target,e.call_monitoring_defect_target,e.collection_call_model_defect_target
)a ) a 
left join(
select 
/*a."MONTH",
a."UCID",*/
a."FUSION_ID",
/*a."ASM_NAME",
a."MANAGER",
a."LOCATION",
a."DEPT",*/
rank() OVER (order by sum(a."Overall Score") desc,a."FUSION_ID") "YTD Global Rank",
sum(a."Overall Score") "YTD Global Total Score"
/*a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Inbound AHT",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Off"*/
from(
select 
a."MONTH",
a."UCID",
a."FUSION_ID",
a."ASM_NAME",
a."MANAGER",
a."LOCATION",
a."DEPT",
rank() OVER (PARTITION by a."MONTH",a."DEPT" ORDER BY (round( coalesce(a."Res Credit Points",0) + coalesce(a."AHT Points",0) + coalesce(a."CMS Usage Points",0)+ coalesce(a."TL Call Monitoring Points",0) +
coalesce(a."Collection call Model Points",0)
,2)) desc,a."MONTH",a."DEPT" ) "Overall Rank",
(round( coalesce(a."Res Credit Points",0) + coalesce(a."AHT Points",0) + coalesce(a."CMS Usage Points",0)+ coalesce(a."TL Call Monitoring Points",0) +
coalesce(a."Collection call Model Points",0)
,2))"Overall Score",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Inbound AHT",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Off"
from (
select 
a.month,c.ucid,a."TL FUSION_ID" "FUSION_ID",c.name "ASM_NAME",c.team_leader "MANAGER",c.location,c.dept,
round(avg(a."Resolution Credits"),2) "Resolution Credits",
rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept ) "Res Credit Rank",
case when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept ) =1 
then 7.5
when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )=2
then 5
else 2.5 end as "Res Credit Points",
/*case when round(avg(a."Resolution Credits"),2) < 2 then 0 else
(case when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )
<=round(d."Out Off"*0.15,0) then 7.5
when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )
<=round(d."Out Off"*0.6,0) then 5 
when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )
<=round(d."Out Off"*0.85,0) then 2.5 
else 0 end )
end as  "Res Credit Points",*/
e.cph_target,
round(avg(a."Inbound AHT"),2) "Inbound AHT",

case when round(avg(a."Inbound AHT"),2) > 660 then 0
 when round(avg(a."Inbound AHT"),2) >=660 then 5-(5*0.80)
when round(avg(a."Inbound AHT"),2) >=630 then 5-(5*0.60)
when round(avg(a."Inbound AHT"),2) >=600 then 5-(5*0.40)
else 5-(5*0.20) end as "AHT Points",
e.ib_aht_target,
round(avg(a."Cms Defect %"),2) "Cms Defect %",
case when round(avg(a."Cms Defect %"),2) <0.5 then 18.75
when round(avg(a."Cms Defect %"),2) < 1.0 then 12.5
when round(avg(a."Cms Defect %"),2) <1.5 then 6.25
else 0
end as "CMS Usage Points",

e.cms_defect_target,
round(avg(a."TL Call Monitoring Defect"),2) "TL Call Monitoring Defect",
case when round(avg(a."TL Call Monitoring Defect"),2) =0 then 3.75
 when round(avg(a."TL Call Monitoring Defect"),2) <= 25 then 2.5 
  when round(avg(a."TL Call Monitoring Defect"),2) <=75  then 1.25
else 0
end as "TL Call Monitoring Points",
e.call_monitoring_defect_target,
round(avg(a."Collection call Model Defect"),2) "Collection call Model Defect",
case when round(avg(a."Collection call Model Defect"),2) < 1.5 then 7.5
when round(avg(a."Collection call Model Defect"),2) < 2.5 then 5
when round(avg(a."Collection call Model Defect"),2) < 3.5 then 2.5
else 0
end "Collection call Model Points",
e.collection_call_model_defect_target,
d."Out Off"
from (
select 
a."MONTH",
a."FUSION_ID",
a."UCID",
a."SUPV_NAME",a."TL FUSION_ID",
a."MANAGER_NAME",
a."LOCATION",
a."DEPT",
a."Overall Score",
a."Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from(
select 
a."MONTH",
a."FUSION_ID",
a."UCID",
a."NAME" "SUPV_NAME",a."TL FUSION_ID",
a."TEAM_LEADER" "MANAGER_NAME",
a."LOCATION",
a."DEPT",
round((a."Res Credit Points"+a."Stella Star Points"+a."Adherence Points"+a."AHT Points"+a."CMS Usage Points"
+a."TL Call Monitoring Points"+a."Collection call Model Points"),2)  "Overall Score",
rank() OVER (PARTITION by month ORDER BY round((a."Res Credit Points"+a."Stella Star Points"+a."Adherence Points"+a."AHT Points"+a."CMS Usage Points"
+a."TL Call Monitoring Points"+a."Collection call Model Points"),2) desc,month ) "Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from (
select 
--"EMPLOYEE ID"--,name,"Team Lead",location,dept
b.month,b.TL_FUSIONID "FUSION_ID",
c.ucid
,b."Team Lead" NAME,c.TL_FUSIONID "TL FUSION_ID", c.team_leader,c.location,c.dept
,round(avg(b."Credit Per Hr"),3) "Resolution Credits"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept ) "Res Credit Rank"
,case when round(avg(b."Credit Per Hr"),3) >2.000 then 
(case when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.15,0) then 11.25 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.6,0) then 7.5 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.85,0) then 3.75 
else 0 end )
else 0
end as "Res Credit Points"
,i.cph_target
--,round(avg(b."Quality Score"),2) "Quality Score"
--,i.QUALITY_TARGET
,round(avg(b."Stella Star Rating"),2) "Stella Star Rating"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Stella Star Rating"),2) desc,b.month,c.dept ) "Stella Star Rank"
, case when round(avg(b."Stella Star Rating"),2) >4.6 then  5-(5*0.20)
when round(avg(b."Stella Star Rating"),2) >=4.5 then  5-(5*0.40)
when round(avg(b."Stella Star Rating"),2) >=4.4 then  5-(5*0.60)
when round(avg(b."Stella Star Rating"),2) >=4.3 then  5-(5*0.80)
else 0 
end as "Stella Star Points"
,i.STAR_TARGET
,round(avg(b."Schedule Adherence"),2) "Schedule Adherence"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Schedule Adherence"),2) desc,b.month,c.dept ) "Adherence Rank"
, case when round(avg(b."Schedule Adherence"),3)>92.50 then 5-(5*0.20)
when round(avg(b."Schedule Adherence"),3)>=90.00 then 5-(5*0.40)
when round(avg(b."Schedule Adherence"),3)>=87.50 then 5-(5*0.60)
when round(avg(b."Schedule Adherence"),3)>=85.00 then 5-(5*0.80)
else 0 end as "Adherence Points"
,i.ADHERENCE_TARGET
,round(avg(b."Inbound AHT"),2) "Inbound AHT"
--,coalesce (j."Inbound AHT",0) "Inbound AHT"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Inbound AHT"),2) desc,b.month,c.dept ) "AHT Rank"
,case when round(avg(b."Inbound AHT"),2)>660 then 0
 when round(avg(b."Inbound AHT"),2) >=660 then 5-(5*0.80)
when round(avg(b."Inbound AHT"),2) >=630 then 5-(5*0.60)
when round(avg(b."Inbound AHT"),2) >=600 then 5-(5*0.40)
else 5-(5*0.20) end as "AHT Points"
,i.ib_aht_target
,round(avg(b."Cms Defect %"),2) "Cms Defect %"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Cms Defect %"),2) asc,b.month,c.dept ) "Cms Defect Rank"
,case when round(avg(b."Cms Defect %"),2) <0.5 then 18.75
when round(avg(b."Cms Defect %"),2) < 1.0 then 12.5
when round(avg(b."Cms Defect %"),2) <1.5 then 6.25
else 0
end as "CMS Usage Points"
,i.CMS_DEFECT_TARGET
,f.qc_per "TL Call Monitoring Defect"
,case when f.qc_per = 0 then  7.5
when f.qc_per <= 25 then  5
when f.qc_per <= 75 then  2.5
else 0
end as  "TL Call Monitoring Points"
,i.call_monitoring_defect_target
,e.defect_per "Collection call Model Defect"
,case when e.defect_per < 1.5 then 7.5
when e.defect_per < 2.5 then 5
when e.defect_per < 3.5 then 2.5
else 0
end as "Collection call Model Points"
,i.collection_call_model_defect_target
,k."Out Of"
from
(
select 
a.month  ,a.ucid,a."EMPLOYEE ID",a.name,a.TL_FUSIONID,a."Team Lead",a.location,a.dept
,rank() OVER (PARTITION by a.month,a.dept ORDER BY
(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") desc,a.dept,a.month ) "Global Rank"
,(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") "Total Points"
,coalesce(a."Credit Per Hr",0) "Credit Per Hr" ,a."Credit Rank",a."Credits Score",a.CPH_TARGET
, coalesce (a."Quality Score",0)  "Quality Score"
,case when a."Quality Rank" is null then 1 else a."Quality Rank" end as "Quality Rank"
,coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0) as "Quality_Score",a.QUALITY_TARGET
,coalesce(a."Stella Star Rating",0) "Stella Star Rating"
,case when a."Stella Star Rank" is null then 1 else a."Stella Star Rank" end as "Stella Star Rank"
,coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0) as "Stella Star Score",a.STAR_TARGET
,coalesce(a."Schedule Adherence",0) "Schedule Adherence",a."Adherence Rank",a."Adherence Score",a.ADHERENCE_TARGET
,coalesce(a."Inbound AHT",0) "Inbound AHT",a."AHT Rank",a."AHT Score",a.IB_AHT_TARGET
,coalesce(a."Cms Defect %",0) "Cms Defect %" ,a."Cms Defect Rank",a."Cms Defect Score",a.CMS_DEFECT_TARGET
,a."Out Of"
from
(
select 
last_day(a.month) month,
a.ucid,
a.fusionid "EMPLOYEE ID",
a.name,
a.TL_FUSIONID,
a.team_leader "Team Lead",
a.location,
a.dept
--,rank() OVER (PARTITION by last_day(a.month),a.dept ORDER BY (coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0)) desc,a.dept,last_day(a.month) ) "Global Rank"
--,(coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0))  "Total Points"
,b."Credit Per Hr",b."Credit Rank",b."Credits Score",
--b.CPH_TARGET
i.CPH_TARGET
,c."Quality Score",c."Quality Rank",c."Quality_Score"
,i.QUALITY_TARGET
,d."Stella Star Rating",d."Stella Star Rank",d."Stella Star Score"
,i.STAR_TARGET
,e."Schedule Adherence",e."Adherence Rank",e."Adherence Score"
,i.ADHERENCE_TARGET
,f."Inbound AHT",f."AHT Rank",f."AHT Score"
,i.IB_AHT_TARGET
,g."Cms Defect %",g."Cms Defect Rank",g."Cms Defect Score"
,i.CMS_DEFECT_TARGET
,h."Out Of"
from asit_roster_table a
left join(
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
--,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
,"CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
,e."CPH_TARGET"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
left join(
select month,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95","CPH_TARGET"
from (
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of"
)a )b
where "CPH_TARGET" is not null)e on last_day(a.rpt_month)=last_day(e.month) and c.dept=e.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of",e."CPH_TARGET"
)a
) b on last_day(a.month)=last_day(b.month) and a.fusionid=b.fusionid
left join(
select last_day(roster_month) month,
a.fusion_id,c.ucid,a.employee_name,c.dept
,coalesce(round(avg(score),2),0) "Quality Score"
,rank() OVER (PARTITION by last_day(roster_month),c.dept ORDER BY coalesce(round(avg(score),2),0) desc,c.dept,last_day(roster_month) )  "Quality Rank"
,b."Out Of"
,case 
when coalesce(round(avg(score),2),0) >=97.50  then 3.75 
when coalesce(round(avg(score),2),0) >=95.20  then 2.5
when coalesce(round(avg(score),2),0) >=90  then 1.25 
else 0
end as
"Quality_Score"
from asit_quality a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.roster_month)=c.month and a.fusion_id=c.fusionid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.roster_month)=b.monthn and b.dept=c.dept
--where a.roster_month=last_day('31-JAN-24') 
--and a.ucid in (select distinct ucid from asit_roster_table where fusionid='105554' ) 
group by last_day(roster_month),a.fusion_id,c.ucid,a.employee_name,c.dept,b."Out Of"

)c on last_day(a.month)=last_day(c.month) and a.fusionid=c.fusion_id
left join(
select 
last_day(a.month) month,a.employee_custom_id,c.dept
--,a.team_leader
,coalesce(round(avg(star_rating),2),0) "Stella Star Rating"
,rank() OVER (PARTITION by last_day(a.month),c.dept  ORDER BY coalesce(round(avg(star_rating),2),0) desc,c.dept ,last_day(a.month) ) "Stella Star Rank"
,b."Out Of"
,case when coalesce(round(avg(star_rating),2),0) >= 4.6 then 4.00
when coalesce(round(avg(star_rating),2),0) >= 4.5 then 3.00 
when coalesce(round(avg(star_rating),2),0) >= 4.4 then 2.00
when coalesce(round(avg(star_rating),2),0) >= 4.3 then 1.00
else 0
end as "Stella Star Score"
from asit_star_rating a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.employee_custom_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
--where  a.month=last_day(a.month)
--and employee_custom_id in ('196400') 
group by last_day(a.month),c.dept,a.employee_custom_id,b."Out Of"
)d on last_day(a.month)=last_day(d.month) and a.fusionid=d.employee_custom_id
left join (
select 
last_day(a.month) month,a.fusion_id,c.dept 
,coalesce(round(adherence_percentage*100,2),0) "Schedule Adherence"
,rank() OVER (PARTITION by last_day(a.month),c.dept ORDER BY coalesce(round(adherence_percentage*100,2),0) desc,c.dept ,last_day(a.month) ) "Adherence Rank"
,b."Out Of"
,case when coalesce(round(adherence_percentage*100,2),0) >=95 then 4.00 
when coalesce(round(adherence_percentage*100,2),0) >=92.5 then 3.00
when coalesce(round(adherence_percentage*100,2),0) >=90 then 2.00 
when coalesce(round(adherence_percentage*100,2),0) >=87.5 then 1.00
else 0
end as
"Adherence Score"
from asit_telephony a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.fusion_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)e on last_day(a.month)=last_day(e.month) and a.fusionid=e.fusion_id
left join (
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
)f on to_char(last_day(a.month),'MON-YY')=f.month and a.fusionid=f.fusionid
left join(
select 
last_day(a.month) month,c.fusionid,a.ucid,c.dept,a.cms_defect_percentage,coalesce(round(a.cms_defect_percentage*100,2),0) "Cms Defect %"
,rank() OVER (PARTITION by a.month ORDER BY coalesce(round(a.cms_defect_percentage*100,2),0) asc,a.month ) "Cms Defect Rank"
,b."Out Of"
,case when coalesce(round(a.cms_defect_percentage*100,2),0) <0.5 then 18.5 
when coalesce(round(a.cms_defect_percentage*100,2),0) <1 then 12.5
when coalesce(round(a.cms_defect_percentage*100,2),0) <=1.5 then 6.25
else 0
end as
"Cms Defect Score"
from asit_cms_defect a
join(
select month,fusionid,ucid,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.ucid=c.ucid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)g on last_day(a.month)=g.month and a.fusionid=g.fusionid
left join(
select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)h on last_day(a.month)=h.monthn and a.dept=h.dept
left join CR_SC_AGNTS_TARGET i on last_day(a.month)=i.month and a.dept=i.dept
where --a.month>=last_day(sysdate)and
 a.dept in ('CCC-R','CCC-R SPANISH','FLEX')
and a.location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and a.designation in ('Agent')
and a.final_status='ACTIVE'
and a.team_leader not in (select name from not_teamleader)
)a)b
join(
select month,fusionid,ucid,name,TL_FUSIONID,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on b.month=c.month and b.TL_FUSIONID=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)d on b.month=d.monthn and c.dept=d.dept
left join (
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end defect_per 
 from asit_tl_impact
)e on b.month=e.month and b.TL_FUSIONID=e.fusionid
left join(
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end QC_per 
 from asit_tl_qc
)f on b.month=f.month and b.TL_FUSIONID=f.fusionid
left join CR_SC_TL_TARGET i on b.month=i.month and c.dept=i.dept
left join(
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
) j on to_char(b.month,'MON-YY')=j.month and b.TL_FUSIONID=j.fusionid
left join (select 
to_char(last_day(month),'MON-YY') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-YY'),dept
)k on to_char(b.month,'MON-YY')=k.monthn and c.dept=k.dept
--where  "EMPLOYEE ID" in('197233')
group by b.month,b.TL_FUSIONID,b."Team Lead"
,c.fusionid,c.ucid,c.TL_FUSIONID ,c.team_leader,c.location,c.dept,
i.cph_target,i.STAR_TARGET,i.ADHERENCE_TARGET,i.CMS_DEFECT_TARGET,i.collection_call_model_defect_target,i.call_monitoring_defect_target,i.ib_aht_target
,e.defect_per,f.QC_per,j."Inbound AHT",k."Out Of"
)a )a ) a 
join(
select month,fusionid,ucid,name,TL_FUSIONID,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Assistant Manager')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a."TL FUSION_ID"=c.fusionid
join(
select month,dept,count(fusionid) "Out Off" from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Assistant Manager')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by  month,dept
)d on a.month=d.month
left join CR_SC_AM_TARGET e on a.month=e.month and c.dept=e.dept
--where a.month>=last_day('01-JAN_24')
--where a."FUSION_ID" in ('195869')
group by a.month,a."TL FUSION_ID",a."MANAGER_NAME",c.ucid,c.name,c.team_leader,c.location,c.dept,d."Out Off"
,e.cph_target,e.ib_aht_target,e.cms_defect_target,e.call_monitoring_defect_target,e.collection_call_model_defect_target
)a ) a 
group by a."FUSION_ID"
)b on a."FUSION_ID"=b."FUSION_ID"
where --a."MONTH" >= last_day('01-FEB-24') and 
a."FUSION_ID" in (vfusionid5)
order by a.month asc,a."Overall Rank";   


            else
            OPEN p_result FOR 
            
select 
to_char(a."MONTH",'MON-YY') MONTH,
a."UCID",
a."FUSION_ID",
a."ASM_NAME",
a."MANAGER",
a."LOCATION",
a."DEPT",
a."Overall Rank",
a."Overall Score",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Inbound AHT",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Off",
b."YTD Global Rank",
b."YTD Global Total Score"
from(
select 
a."MONTH",
a."UCID",
a."FUSION_ID",
a."ASM_NAME",
a."MANAGER",
a."LOCATION",
a."DEPT",
rank() OVER (PARTITION by a."MONTH",a."DEPT" ORDER BY (round( coalesce(a."Res Credit Points",0) + coalesce(a."AHT Points",0) + coalesce(a."CMS Usage Points",0)+ coalesce(a."TL Call Monitoring Points",0) +
coalesce(a."Collection call Model Points",0)
,2)) desc,a."MONTH",a."DEPT" ) "Overall Rank",
(round( coalesce(a."Res Credit Points",0) + coalesce(a."AHT Points",0) + coalesce(a."CMS Usage Points",0)+ coalesce(a."TL Call Monitoring Points",0) +
coalesce(a."Collection call Model Points",0)
,2))"Overall Score",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Inbound AHT",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Off"
from (
select 
a.month,c.ucid,a."TL FUSION_ID" "FUSION_ID",c.name "ASM_NAME",c.team_leader "MANAGER",c.location,c.dept,
round(avg(a."Resolution Credits"),2) "Resolution Credits",
rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept ) "Res Credit Rank",
case when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept ) =1 
then 7.5
when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )=2
then 5
else 2.5 end as "Res Credit Points",
/*case when round(avg(a."Resolution Credits"),2) < 2 then 0 else
(case when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )
<=round(d."Out Off"*0.15,0) then 7.5
when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )
<=round(d."Out Off"*0.6,0) then 5 
when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )
<=round(d."Out Off"*0.85,0) then 2.5 
else 0 end )
end as  "Res Credit Points",*/
e.cph_target,
round(avg(a."Inbound AHT"),2) "Inbound AHT",

case when round(avg(a."Inbound AHT"),2) > 660 then 0
 when round(avg(a."Inbound AHT"),2) >=660 then 5-(5*0.80)
when round(avg(a."Inbound AHT"),2) >=630 then 5-(5*0.60)
when round(avg(a."Inbound AHT"),2) >=600 then 5-(5*0.40)
else 5-(5*0.20) end as "AHT Points",
e.ib_aht_target,
round(avg(a."Cms Defect %"),2) "Cms Defect %",
case when round(avg(a."Cms Defect %"),2) <0.5 then 18.75
when round(avg(a."Cms Defect %"),2) < 1.0 then 12.5
when round(avg(a."Cms Defect %"),2) <1.5 then 6.25
else 0
end as "CMS Usage Points",

e.cms_defect_target,
round(avg(a."TL Call Monitoring Defect"),2) "TL Call Monitoring Defect",
case when round(avg(a."TL Call Monitoring Defect"),2) =0 then 3.75
 when round(avg(a."TL Call Monitoring Defect"),2) <= 25 then 2.5 
  when round(avg(a."TL Call Monitoring Defect"),2) <=75  then 1.25
else 0
end as "TL Call Monitoring Points",
e.call_monitoring_defect_target,
round(avg(a."Collection call Model Defect"),2) "Collection call Model Defect",
case when round(avg(a."Collection call Model Defect"),2) < 1.5 then 7.5
when round(avg(a."Collection call Model Defect"),2) < 2.5 then 5
when round(avg(a."Collection call Model Defect"),2) < 3.5 then 2.5
else 0
end "Collection call Model Points",
e.collection_call_model_defect_target,
d."Out Off"
from (
select 
a."MONTH",
a."FUSION_ID",
a."UCID",
a."SUPV_NAME",a."TL FUSION_ID",
a."MANAGER_NAME",
a."LOCATION",
a."DEPT",
a."Overall Score",
a."Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from(
select 
a."MONTH",
a."FUSION_ID",
a."UCID",
a."NAME" "SUPV_NAME",a."TL FUSION_ID",
a."TEAM_LEADER" "MANAGER_NAME",
a."LOCATION",
a."DEPT",
round((a."Res Credit Points"+a."Stella Star Points"+a."Adherence Points"+a."AHT Points"+a."CMS Usage Points"
+a."TL Call Monitoring Points"+a."Collection call Model Points"),2)  "Overall Score",
rank() OVER (PARTITION by month ORDER BY round((a."Res Credit Points"+a."Stella Star Points"+a."Adherence Points"+a."AHT Points"+a."CMS Usage Points"
+a."TL Call Monitoring Points"+a."Collection call Model Points"),2) desc,month ) "Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from (
select 
--"EMPLOYEE ID"--,name,"Team Lead",location,dept
b.month,b.TL_FUSIONID "FUSION_ID",
c.ucid
,b."Team Lead" NAME,c.TL_FUSIONID "TL FUSION_ID", c.team_leader,c.location,c.dept
,round(avg(b."Credit Per Hr"),3) "Resolution Credits"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept ) "Res Credit Rank"
,case when round(avg(b."Credit Per Hr"),3) >2.000 then 
(case when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.15,0) then 11.25 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.6,0) then 7.5 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.85,0) then 3.75 
else 0 end )
else 0
end as "Res Credit Points"
,i.cph_target
--,round(avg(b."Quality Score"),2) "Quality Score"
--,i.QUALITY_TARGET
,round(avg(b."Stella Star Rating"),2) "Stella Star Rating"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Stella Star Rating"),2) desc,b.month,c.dept ) "Stella Star Rank"
, case when round(avg(b."Stella Star Rating"),2) >4.6 then  5-(5*0.20)
when round(avg(b."Stella Star Rating"),2) >=4.5 then  5-(5*0.40)
when round(avg(b."Stella Star Rating"),2) >=4.4 then  5-(5*0.60)
when round(avg(b."Stella Star Rating"),2) >=4.3 then  5-(5*0.80)
else 0 
end as "Stella Star Points"
,i.STAR_TARGET
,round(avg(b."Schedule Adherence"),2) "Schedule Adherence"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Schedule Adherence"),2) desc,b.month,c.dept ) "Adherence Rank"
, case when round(avg(b."Schedule Adherence"),3)>92.50 then 5-(5*0.20)
when round(avg(b."Schedule Adherence"),3)>=90.00 then 5-(5*0.40)
when round(avg(b."Schedule Adherence"),3)>=87.50 then 5-(5*0.60)
when round(avg(b."Schedule Adherence"),3)>=85.00 then 5-(5*0.80)
else 0 end as "Adherence Points"
,i.ADHERENCE_TARGET
,round(avg(b."Inbound AHT"),2) "Inbound AHT"
--,coalesce (j."Inbound AHT",0) "Inbound AHT"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Inbound AHT"),2) desc,b.month,c.dept ) "AHT Rank"
,case when round(avg(b."Inbound AHT"),2)>660 then 0
 when round(avg(b."Inbound AHT"),2) >=660 then 5-(5*0.80)
when round(avg(b."Inbound AHT"),2) >=630 then 5-(5*0.60)
when round(avg(b."Inbound AHT"),2) >=600 then 5-(5*0.40)
else 5-(5*0.20) end as "AHT Points"
,i.ib_aht_target
,round(avg(b."Cms Defect %"),2) "Cms Defect %"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Cms Defect %"),2) asc,b.month,c.dept ) "Cms Defect Rank"
,case when round(avg(b."Cms Defect %"),2) <0.5 then 18.75
when round(avg(b."Cms Defect %"),2) < 1.0 then 12.5
when round(avg(b."Cms Defect %"),2) <1.5 then 6.25
else 0
end as "CMS Usage Points"
,i.CMS_DEFECT_TARGET
,f.qc_per "TL Call Monitoring Defect"
,case when f.qc_per = 0 then  7.5
when f.qc_per <= 25 then  5
when f.qc_per <= 75 then  2.5
else 0
end as  "TL Call Monitoring Points"
,i.call_monitoring_defect_target
,e.defect_per "Collection call Model Defect"
,case when e.defect_per < 1.5 then 7.5
when e.defect_per < 2.5 then 5
when e.defect_per < 3.5 then 2.5
else 0
end as "Collection call Model Points"
,i.collection_call_model_defect_target
,k."Out Of"
from
(
select 
a.month  ,a.ucid,a."EMPLOYEE ID",a.name,a.TL_FUSIONID,a."Team Lead",a.location,a.dept
,rank() OVER (PARTITION by a.month,a.dept ORDER BY
(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") desc,a.dept,a.month ) "Global Rank"
,(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") "Total Points"
,coalesce(a."Credit Per Hr",0) "Credit Per Hr" ,a."Credit Rank",a."Credits Score",a.CPH_TARGET
, coalesce (a."Quality Score",0)  "Quality Score"
,case when a."Quality Rank" is null then 1 else a."Quality Rank" end as "Quality Rank"
,coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0) as "Quality_Score",a.QUALITY_TARGET
,coalesce(a."Stella Star Rating",0) "Stella Star Rating"
,case when a."Stella Star Rank" is null then 1 else a."Stella Star Rank" end as "Stella Star Rank"
,coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0) as "Stella Star Score",a.STAR_TARGET
,coalesce(a."Schedule Adherence",0) "Schedule Adherence",a."Adherence Rank",a."Adherence Score",a.ADHERENCE_TARGET
,coalesce(a."Inbound AHT",0) "Inbound AHT",a."AHT Rank",a."AHT Score",a.IB_AHT_TARGET
,coalesce(a."Cms Defect %",0) "Cms Defect %" ,a."Cms Defect Rank",a."Cms Defect Score",a.CMS_DEFECT_TARGET
,a."Out Of"
from
(
select 
last_day(a.month) month,
a.ucid,
a.fusionid "EMPLOYEE ID",
a.name,
a.TL_FUSIONID,
a.team_leader "Team Lead",
a.location,
a.dept
--,rank() OVER (PARTITION by last_day(a.month),a.dept ORDER BY (coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0)) desc,a.dept,last_day(a.month) ) "Global Rank"
--,(coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0))  "Total Points"
,b."Credit Per Hr",b."Credit Rank",b."Credits Score",
--b.CPH_TARGET
i.CPH_TARGET
,c."Quality Score",c."Quality Rank",c."Quality_Score"
,i.QUALITY_TARGET
,d."Stella Star Rating",d."Stella Star Rank",d."Stella Star Score"
,i.STAR_TARGET
,e."Schedule Adherence",e."Adherence Rank",e."Adherence Score"
,i.ADHERENCE_TARGET
,f."Inbound AHT",f."AHT Rank",f."AHT Score"
,i.IB_AHT_TARGET
,g."Cms Defect %",g."Cms Defect Rank",g."Cms Defect Score"
,i.CMS_DEFECT_TARGET
,h."Out Of"
from asit_roster_table a
left join(
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
--,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
,"CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
,e."CPH_TARGET"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
left join(
select month,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95","CPH_TARGET"
from (
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of"
)a )b
where "CPH_TARGET" is not null)e on last_day(a.rpt_month)=last_day(e.month) and c.dept=e.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of",e."CPH_TARGET"
)a
) b on last_day(a.month)=last_day(b.month) and a.fusionid=b.fusionid
left join(
select last_day(roster_month) month,
a.fusion_id,c.ucid,a.employee_name,c.dept
,coalesce(round(avg(score),2),0) "Quality Score"
,rank() OVER (PARTITION by last_day(roster_month),c.dept ORDER BY coalesce(round(avg(score),2),0) desc,c.dept,last_day(roster_month) )  "Quality Rank"
,b."Out Of"
,case 
when coalesce(round(avg(score),2),0) >=97.50  then 3.75 
when coalesce(round(avg(score),2),0) >=95.20  then 2.5
when coalesce(round(avg(score),2),0) >=90  then 1.25 
else 0
end as
"Quality_Score"
from asit_quality a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.roster_month)=c.month and a.fusion_id=c.fusionid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.roster_month)=b.monthn and b.dept=c.dept
--where a.roster_month=last_day('31-JAN-24') 
--and a.ucid in (select distinct ucid from asit_roster_table where fusionid='105554' ) 
group by last_day(roster_month),a.fusion_id,c.ucid,a.employee_name,c.dept,b."Out Of"

)c on last_day(a.month)=last_day(c.month) and a.fusionid=c.fusion_id
left join(
select 
last_day(a.month) month,a.employee_custom_id,c.dept
--,a.team_leader
,coalesce(round(avg(star_rating),2),0) "Stella Star Rating"
,rank() OVER (PARTITION by last_day(a.month),c.dept  ORDER BY coalesce(round(avg(star_rating),2),0) desc,c.dept ,last_day(a.month) ) "Stella Star Rank"
,b."Out Of"
,case when coalesce(round(avg(star_rating),2),0) >= 4.6 then 4.00
when coalesce(round(avg(star_rating),2),0) >= 4.5 then 3.00 
when coalesce(round(avg(star_rating),2),0) >= 4.4 then 2.00
when coalesce(round(avg(star_rating),2),0) >= 4.3 then 1.00
else 0
end as "Stella Star Score"
from asit_star_rating a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.employee_custom_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
--where  a.month=last_day(a.month)
--and employee_custom_id in ('196400') 
group by last_day(a.month),c.dept,a.employee_custom_id,b."Out Of"
)d on last_day(a.month)=last_day(d.month) and a.fusionid=d.employee_custom_id
left join (
select 
last_day(a.month) month,a.fusion_id,c.dept 
,coalesce(round(adherence_percentage*100,2),0) "Schedule Adherence"
,rank() OVER (PARTITION by last_day(a.month),c.dept ORDER BY coalesce(round(adherence_percentage*100,2),0) desc,c.dept ,last_day(a.month) ) "Adherence Rank"
,b."Out Of"
,case when coalesce(round(adherence_percentage*100,2),0) >=95 then 4.00 
when coalesce(round(adherence_percentage*100,2),0) >=92.5 then 3.00
when coalesce(round(adherence_percentage*100,2),0) >=90 then 2.00 
when coalesce(round(adherence_percentage*100,2),0) >=87.5 then 1.00
else 0
end as
"Adherence Score"
from asit_telephony a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.fusion_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)e on last_day(a.month)=last_day(e.month) and a.fusionid=e.fusion_id
left join (
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
)f on to_char(last_day(a.month),'MON-YY')=f.month and a.fusionid=f.fusionid
left join(
select 
last_day(a.month) month,c.fusionid,a.ucid,c.dept,a.cms_defect_percentage,coalesce(round(a.cms_defect_percentage*100,2),0) "Cms Defect %"
,rank() OVER (PARTITION by a.month ORDER BY coalesce(round(a.cms_defect_percentage*100,2),0) asc,a.month ) "Cms Defect Rank"
,b."Out Of"
,case when coalesce(round(a.cms_defect_percentage*100,2),0) <0.5 then 18.5 
when coalesce(round(a.cms_defect_percentage*100,2),0) <1 then 12.5
when coalesce(round(a.cms_defect_percentage*100,2),0) <=1.5 then 6.25
else 0
end as
"Cms Defect Score"
from asit_cms_defect a
join(
select month,fusionid,ucid,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.ucid=c.ucid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)g on last_day(a.month)=g.month and a.fusionid=g.fusionid
left join(
select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)h on last_day(a.month)=h.monthn and a.dept=h.dept
left join CR_SC_AGNTS_TARGET i on last_day(a.month)=i.month and a.dept=i.dept
where --a.month>=last_day(sysdate)and
 a.dept in ('CCC-R','CCC-R SPANISH','FLEX')
and a.location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and a.designation in ('Agent')
and a.final_status='ACTIVE'
and a.team_leader not in (select name from not_teamleader)
)a)b
join(
select month,fusionid,ucid,name,TL_FUSIONID,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on b.month=c.month and b.TL_FUSIONID=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)d on b.month=d.monthn and c.dept=d.dept
left join (
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end defect_per 
 from asit_tl_impact
)e on b.month=e.month and b.TL_FUSIONID=e.fusionid
left join(
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end QC_per 
 from asit_tl_qc
)f on b.month=f.month and b.TL_FUSIONID=f.fusionid
left join CR_SC_TL_TARGET i on b.month=i.month and c.dept=i.dept
left join(
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept

) j on to_char(b.month,'MON-YY')=j.month and b.TL_FUSIONID=j.fusionid
left join (select 
to_char(last_day(month),'MON-YY') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-YY'),dept
)k on to_char(b.month,'MON-YY')=k.monthn and c.dept=k.dept
--where  "EMPLOYEE ID" in('197233')
group by b.month,b.TL_FUSIONID,b."Team Lead"
,c.fusionid,c.ucid,c.TL_FUSIONID ,c.team_leader,c.location,c.dept,
i.cph_target,i.STAR_TARGET,i.ADHERENCE_TARGET,i.CMS_DEFECT_TARGET,i.collection_call_model_defect_target,i.call_monitoring_defect_target,i.ib_aht_target
,e.defect_per,f.QC_per,j."Inbound AHT",k."Out Of"
)a )a ) a 
join(
select month,fusionid,ucid,name,TL_FUSIONID,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Assistant Manager')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a."TL FUSION_ID"=c.fusionid
join(
select month,dept,count(fusionid) "Out Off" from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Assistant Manager')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by  month,dept
)d on a.month=d.month
left join CR_SC_AM_TARGET e on a.month=e.month and c.dept=e.dept
--where a.month>=last_day('01-JAN_24')
--where a."FUSION_ID" in ('195869')
group by a.month,a."TL FUSION_ID",a."MANAGER_NAME",c.ucid,c.name,c.team_leader,c.location,c.dept,d."Out Off"
,e.cph_target,e.ib_aht_target,e.cms_defect_target,e.call_monitoring_defect_target,e.collection_call_model_defect_target
)a ) a 
left join(
select 
/*a."MONTH",
a."UCID",*/
a."FUSION_ID",
/*a."ASM_NAME",
a."MANAGER",
a."LOCATION",
a."DEPT",*/
rank() OVER (order by sum(a."Overall Score") desc,a."FUSION_ID") "YTD Global Rank",
sum(a."Overall Score") "YTD Global Total Score"
/*a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Inbound AHT",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Off"*/
from(
select 
a."MONTH",
a."UCID",
a."FUSION_ID",
a."ASM_NAME",
a."MANAGER",
a."LOCATION",
a."DEPT",
rank() OVER (PARTITION by a."MONTH",a."DEPT" ORDER BY (round( coalesce(a."Res Credit Points",0) + coalesce(a."AHT Points",0) + coalesce(a."CMS Usage Points",0)+ coalesce(a."TL Call Monitoring Points",0) +
coalesce(a."Collection call Model Points",0)
,2)) desc,a."MONTH",a."DEPT" ) "Overall Rank",
(round( coalesce(a."Res Credit Points",0) + coalesce(a."AHT Points",0) + coalesce(a."CMS Usage Points",0)+ coalesce(a."TL Call Monitoring Points",0) +
coalesce(a."Collection call Model Points",0)
,2))"Overall Score",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Inbound AHT",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Off"
from (
select 
a.month,c.ucid,a."TL FUSION_ID" "FUSION_ID",c.name "ASM_NAME",c.team_leader "MANAGER",c.location,c.dept,
round(avg(a."Resolution Credits"),2) "Resolution Credits",
rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept ) "Res Credit Rank",
case when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept ) =1 
then 7.5
when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )=2
then 5
else 2.5 end as "Res Credit Points",
/*case when round(avg(a."Resolution Credits"),2) < 2 then 0 else
(case when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )
<=round(d."Out Off"*0.15,0) then 7.5
when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )
<=round(d."Out Off"*0.6,0) then 5 
when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )
<=round(d."Out Off"*0.85,0) then 2.5 
else 0 end )
end as  "Res Credit Points",*/
e.cph_target,
round(avg(a."Inbound AHT"),2) "Inbound AHT",

case when round(avg(a."Inbound AHT"),2) > 660 then 0
 when round(avg(a."Inbound AHT"),2) >=660 then 5-(5*0.80)
when round(avg(a."Inbound AHT"),2) >=630 then 5-(5*0.60)
when round(avg(a."Inbound AHT"),2) >=600 then 5-(5*0.40)
else 5-(5*0.20) end as "AHT Points",
e.ib_aht_target,
round(avg(a."Cms Defect %"),2) "Cms Defect %",
case when round(avg(a."Cms Defect %"),2) <0.5 then 18.75
when round(avg(a."Cms Defect %"),2) < 1.0 then 12.5
when round(avg(a."Cms Defect %"),2) <1.5 then 6.25
else 0
end as "CMS Usage Points",

e.cms_defect_target,
round(avg(a."TL Call Monitoring Defect"),2) "TL Call Monitoring Defect",
case when round(avg(a."TL Call Monitoring Defect"),2) =0 then 3.75
 when round(avg(a."TL Call Monitoring Defect"),2) <= 25 then 2.5 
  when round(avg(a."TL Call Monitoring Defect"),2) <=75  then 1.25
else 0
end as "TL Call Monitoring Points",
e.call_monitoring_defect_target,
round(avg(a."Collection call Model Defect"),2) "Collection call Model Defect",
case when round(avg(a."Collection call Model Defect"),2) < 1.5 then 7.5
when round(avg(a."Collection call Model Defect"),2) < 2.5 then 5
when round(avg(a."Collection call Model Defect"),2) < 3.5 then 2.5
else 0
end "Collection call Model Points",
e.collection_call_model_defect_target,
d."Out Off"
from (
select 
a."MONTH",
a."FUSION_ID",
a."UCID",
a."SUPV_NAME",a."TL FUSION_ID",
a."MANAGER_NAME",
a."LOCATION",
a."DEPT",
a."Overall Score",
a."Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from(
select 
a."MONTH",
a."FUSION_ID",
a."UCID",
a."NAME" "SUPV_NAME",a."TL FUSION_ID",
a."TEAM_LEADER" "MANAGER_NAME",
a."LOCATION",
a."DEPT",
round((a."Res Credit Points"+a."Stella Star Points"+a."Adherence Points"+a."AHT Points"+a."CMS Usage Points"
+a."TL Call Monitoring Points"+a."Collection call Model Points"),2)  "Overall Score",
rank() OVER (PARTITION by month ORDER BY round((a."Res Credit Points"+a."Stella Star Points"+a."Adherence Points"+a."AHT Points"+a."CMS Usage Points"
+a."TL Call Monitoring Points"+a."Collection call Model Points"),2) desc,month ) "Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from (
select 
--"EMPLOYEE ID"--,name,"Team Lead",location,dept
b.month,b.TL_FUSIONID "FUSION_ID",
c.ucid
,b."Team Lead" NAME,c.TL_FUSIONID "TL FUSION_ID", c.team_leader,c.location,c.dept
,round(avg(b."Credit Per Hr"),3) "Resolution Credits"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept ) "Res Credit Rank"
,case when round(avg(b."Credit Per Hr"),3) >2.000 then 
(case when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.15,0) then 11.25 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.6,0) then 7.5 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.85,0) then 3.75 
else 0 end )
else 0
end as "Res Credit Points"
,i.cph_target
--,round(avg(b."Quality Score"),2) "Quality Score"
--,i.QUALITY_TARGET
,round(avg(b."Stella Star Rating"),2) "Stella Star Rating"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Stella Star Rating"),2) desc,b.month,c.dept ) "Stella Star Rank"
, case when round(avg(b."Stella Star Rating"),2) >4.6 then  5-(5*0.20)
when round(avg(b."Stella Star Rating"),2) >=4.5 then  5-(5*0.40)
when round(avg(b."Stella Star Rating"),2) >=4.4 then  5-(5*0.60)
when round(avg(b."Stella Star Rating"),2) >=4.3 then  5-(5*0.80)
else 0 
end as "Stella Star Points"
,i.STAR_TARGET
,round(avg(b."Schedule Adherence"),2) "Schedule Adherence"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Schedule Adherence"),2) desc,b.month,c.dept ) "Adherence Rank"
, case when round(avg(b."Schedule Adherence"),3)>92.50 then 5-(5*0.20)
when round(avg(b."Schedule Adherence"),3)>=90.00 then 5-(5*0.40)
when round(avg(b."Schedule Adherence"),3)>=87.50 then 5-(5*0.60)
when round(avg(b."Schedule Adherence"),3)>=85.00 then 5-(5*0.80)
else 0 end as "Adherence Points"
,i.ADHERENCE_TARGET
,round(avg(b."Inbound AHT"),2) "Inbound AHT"
--,coalesce (j."Inbound AHT",0) "Inbound AHT"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Inbound AHT"),2) desc,b.month,c.dept ) "AHT Rank"
,case when round(avg(b."Inbound AHT"),2)>660 then 0
 when round(avg(b."Inbound AHT"),2) >=660 then 5-(5*0.80)
when round(avg(b."Inbound AHT"),2) >=630 then 5-(5*0.60)
when round(avg(b."Inbound AHT"),2) >=600 then 5-(5*0.40)
else 5-(5*0.20) end as "AHT Points"
,i.ib_aht_target
,round(avg(b."Cms Defect %"),2) "Cms Defect %"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Cms Defect %"),2) asc,b.month,c.dept ) "Cms Defect Rank"
,case when round(avg(b."Cms Defect %"),2) <0.5 then 18.75
when round(avg(b."Cms Defect %"),2) < 1.0 then 12.5
when round(avg(b."Cms Defect %"),2) <1.5 then 6.25
else 0
end as "CMS Usage Points"
,i.CMS_DEFECT_TARGET
,f.qc_per "TL Call Monitoring Defect"
,case when f.qc_per = 0 then  7.5
when f.qc_per <= 25 then  5
when f.qc_per <= 75 then  2.5
else 0
end as  "TL Call Monitoring Points"
,i.call_monitoring_defect_target
,e.defect_per "Collection call Model Defect"
,case when e.defect_per < 1.5 then 7.5
when e.defect_per < 2.5 then 5
when e.defect_per < 3.5 then 2.5
else 0
end as "Collection call Model Points"
,i.collection_call_model_defect_target
,k."Out Of"
from
(
select 
a.month  ,a.ucid,a."EMPLOYEE ID",a.name,a.TL_FUSIONID,a."Team Lead",a.location,a.dept
,rank() OVER (PARTITION by a.month,a.dept ORDER BY
(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") desc,a.dept,a.month ) "Global Rank"
,(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") "Total Points"
,coalesce(a."Credit Per Hr",0) "Credit Per Hr" ,a."Credit Rank",a."Credits Score",a.CPH_TARGET
, coalesce (a."Quality Score",0)  "Quality Score"
,case when a."Quality Rank" is null then 1 else a."Quality Rank" end as "Quality Rank"
,coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0) as "Quality_Score",a.QUALITY_TARGET
,coalesce(a."Stella Star Rating",0) "Stella Star Rating"
,case when a."Stella Star Rank" is null then 1 else a."Stella Star Rank" end as "Stella Star Rank"
,coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0) as "Stella Star Score",a.STAR_TARGET
,coalesce(a."Schedule Adherence",0) "Schedule Adherence",a."Adherence Rank",a."Adherence Score",a.ADHERENCE_TARGET
,coalesce(a."Inbound AHT",0) "Inbound AHT",a."AHT Rank",a."AHT Score",a.IB_AHT_TARGET
,coalesce(a."Cms Defect %",0) "Cms Defect %" ,a."Cms Defect Rank",a."Cms Defect Score",a.CMS_DEFECT_TARGET
,a."Out Of"
from
(
select 
last_day(a.month) month,
a.ucid,
a.fusionid "EMPLOYEE ID",
a.name,
a.TL_FUSIONID,
a.team_leader "Team Lead",
a.location,
a.dept
--,rank() OVER (PARTITION by last_day(a.month),a.dept ORDER BY (coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0)) desc,a.dept,last_day(a.month) ) "Global Rank"
--,(coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0))  "Total Points"
,b."Credit Per Hr",b."Credit Rank",b."Credits Score",
--b.CPH_TARGET
i.CPH_TARGET
,c."Quality Score",c."Quality Rank",c."Quality_Score"
,i.QUALITY_TARGET
,d."Stella Star Rating",d."Stella Star Rank",d."Stella Star Score"
,i.STAR_TARGET
,e."Schedule Adherence",e."Adherence Rank",e."Adherence Score"
,i.ADHERENCE_TARGET
,f."Inbound AHT",f."AHT Rank",f."AHT Score"
,i.IB_AHT_TARGET
,g."Cms Defect %",g."Cms Defect Rank",g."Cms Defect Score"
,i.CMS_DEFECT_TARGET
,h."Out Of"
from asit_roster_table a
left join(
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
--,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
,"CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
,e."CPH_TARGET"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
left join(
select month,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95","CPH_TARGET"
from (
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of"
)a )b
where "CPH_TARGET" is not null)e on last_day(a.rpt_month)=last_day(e.month) and c.dept=e.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of",e."CPH_TARGET"
)a
) b on last_day(a.month)=last_day(b.month) and a.fusionid=b.fusionid
left join(
select last_day(roster_month) month,
a.fusion_id,c.ucid,a.employee_name,c.dept
,coalesce(round(avg(score),2),0) "Quality Score"
,rank() OVER (PARTITION by last_day(roster_month),c.dept ORDER BY coalesce(round(avg(score),2),0) desc,c.dept,last_day(roster_month) )  "Quality Rank"
,b."Out Of"
,case 
when coalesce(round(avg(score),2),0) >=97.50  then 3.75 
when coalesce(round(avg(score),2),0) >=95.20  then 2.5
when coalesce(round(avg(score),2),0) >=90  then 1.25 
else 0
end as
"Quality_Score"
from asit_quality a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.roster_month)=c.month and a.fusion_id=c.fusionid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.roster_month)=b.monthn and b.dept=c.dept
--where a.roster_month=last_day('31-JAN-24') 
--and a.ucid in (select distinct ucid from asit_roster_table where fusionid='105554' ) 
group by last_day(roster_month),a.fusion_id,c.ucid,a.employee_name,c.dept,b."Out Of"

)c on last_day(a.month)=last_day(c.month) and a.fusionid=c.fusion_id
left join(
select 
last_day(a.month) month,a.employee_custom_id,c.dept
--,a.team_leader
,coalesce(round(avg(star_rating),2),0) "Stella Star Rating"
,rank() OVER (PARTITION by last_day(a.month),c.dept  ORDER BY coalesce(round(avg(star_rating),2),0) desc,c.dept ,last_day(a.month) ) "Stella Star Rank"
,b."Out Of"
,case when coalesce(round(avg(star_rating),2),0) >= 4.6 then 4.00
when coalesce(round(avg(star_rating),2),0) >= 4.5 then 3.00 
when coalesce(round(avg(star_rating),2),0) >= 4.4 then 2.00
when coalesce(round(avg(star_rating),2),0) >= 4.3 then 1.00
else 0
end as "Stella Star Score"
from asit_star_rating a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.employee_custom_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
--where  a.month=last_day(a.month)
--and employee_custom_id in ('196400') 
group by last_day(a.month),c.dept,a.employee_custom_id,b."Out Of"
)d on last_day(a.month)=last_day(d.month) and a.fusionid=d.employee_custom_id
left join (
select 
last_day(a.month) month,a.fusion_id,c.dept 
,coalesce(round(adherence_percentage*100,2),0) "Schedule Adherence"
,rank() OVER (PARTITION by last_day(a.month),c.dept ORDER BY coalesce(round(adherence_percentage*100,2),0) desc,c.dept ,last_day(a.month) ) "Adherence Rank"
,b."Out Of"
,case when coalesce(round(adherence_percentage*100,2),0) >=95 then 4.00 
when coalesce(round(adherence_percentage*100,2),0) >=92.5 then 3.00
when coalesce(round(adherence_percentage*100,2),0) >=90 then 2.00 
when coalesce(round(adherence_percentage*100,2),0) >=87.5 then 1.00
else 0
end as
"Adherence Score"
from asit_telephony a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.fusion_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)e on last_day(a.month)=last_day(e.month) and a.fusionid=e.fusion_id
left join (
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
)f on to_char(last_day(a.month),'MON-YY')=f.month and a.fusionid=f.fusionid
left join(
select 
last_day(a.month) month,c.fusionid,a.ucid,c.dept,a.cms_defect_percentage,coalesce(round(a.cms_defect_percentage*100,2),0) "Cms Defect %"
,rank() OVER (PARTITION by a.month ORDER BY coalesce(round(a.cms_defect_percentage*100,2),0) asc,a.month ) "Cms Defect Rank"
,b."Out Of"
,case when coalesce(round(a.cms_defect_percentage*100,2),0) <0.5 then 18.5 
when coalesce(round(a.cms_defect_percentage*100,2),0) <1 then 12.5
when coalesce(round(a.cms_defect_percentage*100,2),0) <=1.5 then 6.25
else 0
end as
"Cms Defect Score"
from asit_cms_defect a
join(
select month,fusionid,ucid,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.ucid=c.ucid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)g on last_day(a.month)=g.month and a.fusionid=g.fusionid
left join(
select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)h on last_day(a.month)=h.monthn and a.dept=h.dept
left join CR_SC_AGNTS_TARGET i on last_day(a.month)=i.month and a.dept=i.dept
where --a.month>=last_day(sysdate)and
 a.dept in ('CCC-R','CCC-R SPANISH','FLEX')
and a.location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and a.designation in ('Agent')
and a.final_status='ACTIVE'
and a.team_leader not in (select name from not_teamleader)
)a)b
join(
select month,fusionid,ucid,name,TL_FUSIONID,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on b.month=c.month and b.TL_FUSIONID=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)d on b.month=d.monthn and c.dept=d.dept
left join (
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end defect_per 
 from asit_tl_impact
)e on b.month=e.month and b.TL_FUSIONID=e.fusionid
left join(
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end QC_per 
 from asit_tl_qc
)f on b.month=f.month and b.TL_FUSIONID=f.fusionid
left join CR_SC_TL_TARGET i on b.month=i.month and c.dept=i.dept
left join(
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
) j on to_char(b.month,'MON-YY')=j.month and b.TL_FUSIONID=j.fusionid
left join (select 
to_char(last_day(month),'MON-YY') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-YY'),dept
)k on to_char(b.month,'MON-YY')=k.monthn and c.dept=k.dept
--where  "EMPLOYEE ID" in('197233')
group by b.month,b.TL_FUSIONID,b."Team Lead"
,c.fusionid,c.ucid,c.TL_FUSIONID ,c.team_leader,c.location,c.dept,
i.cph_target,i.STAR_TARGET,i.ADHERENCE_TARGET,i.CMS_DEFECT_TARGET,i.collection_call_model_defect_target,i.call_monitoring_defect_target,i.ib_aht_target
,e.defect_per,f.QC_per,j."Inbound AHT",k."Out Of"
)a )a ) a 
join(
select month,fusionid,ucid,name,TL_FUSIONID,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Assistant Manager')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a."TL FUSION_ID"=c.fusionid
join(
select month,dept,count(fusionid) "Out Off" from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Assistant Manager')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by  month,dept
)d on a.month=d.month
left join CR_SC_AM_TARGET e on a.month=e.month and c.dept=e.dept
--where a.month>=last_day('01-JAN_24')
--where a."FUSION_ID" in ('195869')
group by a.month,a."TL FUSION_ID",a."MANAGER_NAME",c.ucid,c.name,c.team_leader,c.location,c.dept,d."Out Off"
,e.cph_target,e.ib_aht_target,e.cms_defect_target,e.call_monitoring_defect_target,e.collection_call_model_defect_target
)a ) a 
group by a."FUSION_ID"
)b on a."FUSION_ID"=b."FUSION_ID"
where a."MONTH" >= last_day(period)
and a."FUSION_ID" in (vfusionid5)
order by a.month asc,a."Overall Rank";   

  end if;
  END CR_SC_MTD_AM;
  
 PROCEDURE CR_SC_YTD_AM (
    vfusionid6 in VARCHAR2, p_result OUT SYS_REFCURSOR) is 
  BEGIN
      if(vfusionid6 is null) then       
            OPEN p_result FOR   

select * from (
select 
/*a."MONTH",
a."UCID",*/
a."FUSION_ID" "EMPLOYEE ID",
/*a."ASM_NAME",
a."MANAGER",
a."LOCATION",
a."DEPT",*/
rank() OVER (order by sum(a."Overall Score") desc,a."FUSION_ID") "Global Rank",
sum(a."Overall Score") "Total Points",
round(avg(a."Resolution Credits"),3) "Credit Per Hr" ,
--a."Res Credit Rank",
--a."Res Credit Points",
--a."CPH_TARGET",
round(avg(a."Inbound AHT"),3) "Inbound AHT",
--a."AHT Points",
--a."IB_AHT_TARGET",
round(avg(a."Cms Defect %"),3) "Cms Defect %",
--a."CMS Usage Points",
--a."CMS_DEFECT_TARGET",
round(avg(a."TL Call Monitoring Defect"),3) "TL Call Monitoring Defect",
--a."TL Call Monitoring Points",
--a."CALL_MONITORING_DEFECT_TARGET",
round(avg(a."Collection call Model Defect"),3)  "Collection call Model Defect" 
--a."Collection call Model Points",
--a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
--a."Out Off"*/
from(
select 
a."MONTH",
a."UCID",
a."FUSION_ID",
a."ASM_NAME",
a."MANAGER",
a."LOCATION",
a."DEPT",
rank() OVER (PARTITION by a."MONTH",a."DEPT" ORDER BY (round( coalesce(a."Res Credit Points",0) + coalesce(a."AHT Points",0) + coalesce(a."CMS Usage Points",0)+ coalesce(a."TL Call Monitoring Points",0) +
coalesce(a."Collection call Model Points",0)
,2)) desc,a."MONTH",a."DEPT" ) "Overall Rank",
(round( coalesce(a."Res Credit Points",0) + coalesce(a."AHT Points",0) + coalesce(a."CMS Usage Points",0)+ coalesce(a."TL Call Monitoring Points",0) +
coalesce(a."Collection call Model Points",0)
,2))"Overall Score",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Inbound AHT",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Off"
from (
select 
a.month,c.ucid,a."TL FUSION_ID" "FUSION_ID",c.name "ASM_NAME",c.team_leader "MANAGER",c.location,c.dept,
round(avg(a."Resolution Credits"),2) "Resolution Credits",
rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept ) "Res Credit Rank",
case when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept ) =1 
then 7.5
when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )=2
then 5
else 2.5 end as "Res Credit Points",
/*case when round(avg(a."Resolution Credits"),2) < 2 then 0 else
(case when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )
<=round(d."Out Off"*0.15,0) then 7.5
when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )
<=round(d."Out Off"*0.6,0) then 5 
when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )
<=round(d."Out Off"*0.85,0) then 2.5 
else 0 end )
end as  "Res Credit Points",*/
e.cph_target,
round(avg(a."Inbound AHT"),2) "Inbound AHT",

case when round(avg(a."Inbound AHT"),2) > 660 then 0
 when round(avg(a."Inbound AHT"),2) >=660 then 5-(5*0.80)
when round(avg(a."Inbound AHT"),2) >=630 then 5-(5*0.60)
when round(avg(a."Inbound AHT"),2) >=600 then 5-(5*0.40)
else 5-(5*0.20) end as "AHT Points",
e.ib_aht_target,
round(avg(a."Cms Defect %"),2) "Cms Defect %",
case when round(avg(a."Cms Defect %"),2) <0.5 then 18.75
when round(avg(a."Cms Defect %"),2) < 1.0 then 12.5
when round(avg(a."Cms Defect %"),2) <1.5 then 6.25
else 0
end as "CMS Usage Points",

e.cms_defect_target,
round(avg(a."TL Call Monitoring Defect"),2) "TL Call Monitoring Defect",
case when round(avg(a."TL Call Monitoring Defect"),2) =0 then 3.75
 when round(avg(a."TL Call Monitoring Defect"),2) <= 25 then 2.5 
  when round(avg(a."TL Call Monitoring Defect"),2) <=75  then 1.25
else 0
end as "TL Call Monitoring Points",
e.call_monitoring_defect_target,
round(avg(a."Collection call Model Defect"),2) "Collection call Model Defect",
case when round(avg(a."Collection call Model Defect"),2) < 1.5 then 7.5
when round(avg(a."Collection call Model Defect"),2) < 2.5 then 5
when round(avg(a."Collection call Model Defect"),2) < 3.5 then 2.5
else 0
end "Collection call Model Points",
e.collection_call_model_defect_target,
d."Out Off"
from (
select 
a."MONTH",
a."FUSION_ID",
a."UCID",
a."SUPV_NAME",a."TL FUSION_ID",
a."MANAGER_NAME",
a."LOCATION",
a."DEPT",
a."Overall Score",
a."Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from(
select 
a."MONTH",
a."FUSION_ID",
a."UCID",
a."NAME" "SUPV_NAME",a."TL FUSION_ID",
a."TEAM_LEADER" "MANAGER_NAME",
a."LOCATION",
a."DEPT",
round((a."Res Credit Points"+a."Stella Star Points"+a."Adherence Points"+a."AHT Points"+a."CMS Usage Points"
+a."TL Call Monitoring Points"+a."Collection call Model Points"),2)  "Overall Score",
rank() OVER (PARTITION by month ORDER BY round((a."Res Credit Points"+a."Stella Star Points"+a."Adherence Points"+a."AHT Points"+a."CMS Usage Points"
+a."TL Call Monitoring Points"+a."Collection call Model Points"),2) desc,month ) "Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from (
select 
--"EMPLOYEE ID"--,name,"Team Lead",location,dept
b.month,b.TL_FUSIONID "FUSION_ID",
c.ucid
,b."Team Lead" NAME,c.TL_FUSIONID "TL FUSION_ID", c.team_leader,c.location,c.dept
,round(avg(b."Credit Per Hr"),3) "Resolution Credits"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept ) "Res Credit Rank"
,case when round(avg(b."Credit Per Hr"),3) >2.000 then 
(case when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.15,0) then 11.25 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.6,0) then 7.5 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.85,0) then 3.75 
else 0 end )
else 0
end as "Res Credit Points"
,i.cph_target
--,round(avg(b."Quality Score"),2) "Quality Score"
--,i.QUALITY_TARGET
,round(avg(b."Stella Star Rating"),2) "Stella Star Rating"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Stella Star Rating"),2) desc,b.month,c.dept ) "Stella Star Rank"
, case when round(avg(b."Stella Star Rating"),2) >4.6 then  5-(5*0.20)
when round(avg(b."Stella Star Rating"),2) >=4.5 then  5-(5*0.40)
when round(avg(b."Stella Star Rating"),2) >=4.4 then  5-(5*0.60)
when round(avg(b."Stella Star Rating"),2) >=4.3 then  5-(5*0.80)
else 0 
end as "Stella Star Points"
,i.STAR_TARGET
,round(avg(b."Schedule Adherence"),2) "Schedule Adherence"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Schedule Adherence"),2) desc,b.month,c.dept ) "Adherence Rank"
, case when round(avg(b."Schedule Adherence"),3)>92.50 then 5-(5*0.20)
when round(avg(b."Schedule Adherence"),3)>=90.00 then 5-(5*0.40)
when round(avg(b."Schedule Adherence"),3)>=87.50 then 5-(5*0.60)
when round(avg(b."Schedule Adherence"),3)>=85.00 then 5-(5*0.80)
else 0 end as "Adherence Points"
,i.ADHERENCE_TARGET
,round(avg(b."Inbound AHT"),2) "Inbound AHT"
--,coalesce (j."Inbound AHT",0) "Inbound AHT"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Inbound AHT"),2) desc,b.month,c.dept ) "AHT Rank"
,case when round(avg(b."Inbound AHT"),2)>660 then 0
 when round(avg(b."Inbound AHT"),2) >=660 then 5-(5*0.80)
when round(avg(b."Inbound AHT"),2) >=630 then 5-(5*0.60)
when round(avg(b."Inbound AHT"),2) >=600 then 5-(5*0.40)
else 5-(5*0.20) end as "AHT Points"
,i.ib_aht_target
,round(avg(b."Cms Defect %"),2) "Cms Defect %"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Cms Defect %"),2) asc,b.month,c.dept ) "Cms Defect Rank"
,case when round(avg(b."Cms Defect %"),2) <0.5 then 18.75
when round(avg(b."Cms Defect %"),2) < 1.0 then 12.5
when round(avg(b."Cms Defect %"),2) <1.5 then 6.25
else 0
end as "CMS Usage Points"
,i.CMS_DEFECT_TARGET
,f.qc_per "TL Call Monitoring Defect"
,case when f.qc_per = 0 then  7.5
when f.qc_per <= 25 then  5
when f.qc_per <= 75 then  2.5
else 0
end as  "TL Call Monitoring Points"
,i.call_monitoring_defect_target
,e.defect_per "Collection call Model Defect"
,case when e.defect_per < 1.5 then 7.5
when e.defect_per < 2.5 then 5
when e.defect_per < 3.5 then 2.5
else 0
end as "Collection call Model Points"
,i.collection_call_model_defect_target
,k."Out Of"
from
(
select 
a.month  ,a.ucid,a."EMPLOYEE ID",a.name,a.TL_FUSIONID,a."Team Lead",a.location,a.dept
,rank() OVER (PARTITION by a.month,a.dept ORDER BY
(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") desc,a.dept,a.month ) "Global Rank"
,(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") "Total Points"
,coalesce(a."Credit Per Hr",0) "Credit Per Hr" ,a."Credit Rank",a."Credits Score",a.CPH_TARGET
, coalesce (a."Quality Score",0)  "Quality Score"
,case when a."Quality Rank" is null then 1 else a."Quality Rank" end as "Quality Rank"
,coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0) as "Quality_Score",a.QUALITY_TARGET
,coalesce(a."Stella Star Rating",0) "Stella Star Rating"
,case when a."Stella Star Rank" is null then 1 else a."Stella Star Rank" end as "Stella Star Rank"
,coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0) as "Stella Star Score",a.STAR_TARGET
,coalesce(a."Schedule Adherence",0) "Schedule Adherence",a."Adherence Rank",a."Adherence Score",a.ADHERENCE_TARGET
,coalesce(a."Inbound AHT",0) "Inbound AHT",a."AHT Rank",a."AHT Score",a.IB_AHT_TARGET
,coalesce(a."Cms Defect %",0) "Cms Defect %" ,a."Cms Defect Rank",a."Cms Defect Score",a.CMS_DEFECT_TARGET
,a."Out Of"
from
(
select 
last_day(a.month) month,
a.ucid,
a.fusionid "EMPLOYEE ID",
a.name,
a.TL_FUSIONID,
a.team_leader "Team Lead",
a.location,
a.dept
--,rank() OVER (PARTITION by last_day(a.month),a.dept ORDER BY (coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0)) desc,a.dept,last_day(a.month) ) "Global Rank"
--,(coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0))  "Total Points"
,b."Credit Per Hr",b."Credit Rank",b."Credits Score",
--b.CPH_TARGET
i.CPH_TARGET
,c."Quality Score",c."Quality Rank",c."Quality_Score"
,i.QUALITY_TARGET
,d."Stella Star Rating",d."Stella Star Rank",d."Stella Star Score"
,i.STAR_TARGET
,e."Schedule Adherence",e."Adherence Rank",e."Adherence Score"
,i.ADHERENCE_TARGET
,f."Inbound AHT",f."AHT Rank",f."AHT Score"
,i.IB_AHT_TARGET
,g."Cms Defect %",g."Cms Defect Rank",g."Cms Defect Score"
,i.CMS_DEFECT_TARGET
,h."Out Of"
from asit_roster_table a
left join(
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
--,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
,"CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
,e."CPH_TARGET"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
left join(
select month,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95","CPH_TARGET"
from (
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of"
)a )b
where "CPH_TARGET" is not null)e on last_day(a.rpt_month)=last_day(e.month) and c.dept=e.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of",e."CPH_TARGET"
)a
) b on last_day(a.month)=last_day(b.month) and a.fusionid=b.fusionid
left join(
select last_day(roster_month) month,
a.fusion_id,c.ucid,a.employee_name,c.dept
,coalesce(round(avg(score),2),0) "Quality Score"
,rank() OVER (PARTITION by last_day(roster_month),c.dept ORDER BY coalesce(round(avg(score),2),0) desc,c.dept,last_day(roster_month) )  "Quality Rank"
,b."Out Of"
,case 
when coalesce(round(avg(score),2),0) >=97.50  then 3.75 
when coalesce(round(avg(score),2),0) >=95.20  then 2.5
when coalesce(round(avg(score),2),0) >=90  then 1.25 
else 0
end as
"Quality_Score"
from asit_quality a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.roster_month)=c.month and a.fusion_id=c.fusionid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.roster_month)=b.monthn and b.dept=c.dept
--where a.roster_month=last_day('31-JAN-24') 
--and a.ucid in (select distinct ucid from asit_roster_table where fusionid='105554' ) 
group by last_day(roster_month),a.fusion_id,c.ucid,a.employee_name,c.dept,b."Out Of"

)c on last_day(a.month)=last_day(c.month) and a.fusionid=c.fusion_id
left join(
select 
last_day(a.month) month,a.employee_custom_id,c.dept
--,a.team_leader
,coalesce(round(avg(star_rating),2),0) "Stella Star Rating"
,rank() OVER (PARTITION by last_day(a.month),c.dept  ORDER BY coalesce(round(avg(star_rating),2),0) desc,c.dept ,last_day(a.month) ) "Stella Star Rank"
,b."Out Of"
,case when coalesce(round(avg(star_rating),2),0) >= 4.6 then 4.00
when coalesce(round(avg(star_rating),2),0) >= 4.5 then 3.00 
when coalesce(round(avg(star_rating),2),0) >= 4.4 then 2.00
when coalesce(round(avg(star_rating),2),0) >= 4.3 then 1.00
else 0
end as "Stella Star Score"
from asit_star_rating a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.employee_custom_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
--where  a.month=last_day(a.month)
--and employee_custom_id in ('196400') 
group by last_day(a.month),c.dept,a.employee_custom_id,b."Out Of"
)d on last_day(a.month)=last_day(d.month) and a.fusionid=d.employee_custom_id
left join (
select 
last_day(a.month) month,a.fusion_id,c.dept 
,coalesce(round(adherence_percentage*100,2),0) "Schedule Adherence"
,rank() OVER (PARTITION by last_day(a.month),c.dept ORDER BY coalesce(round(adherence_percentage*100,2),0) desc,c.dept ,last_day(a.month) ) "Adherence Rank"
,b."Out Of"
,case when coalesce(round(adherence_percentage*100,2),0) >=95 then 4.00 
when coalesce(round(adherence_percentage*100,2),0) >=92.5 then 3.00
when coalesce(round(adherence_percentage*100,2),0) >=90 then 2.00 
when coalesce(round(adherence_percentage*100,2),0) >=87.5 then 1.00
else 0
end as
"Adherence Score"
from asit_telephony a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.fusion_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)e on last_day(a.month)=last_day(e.month) and a.fusionid=e.fusion_id
left join (
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
)f on to_char(last_day(a.month),'MON-YY')=f.month and a.fusionid=f.fusionid
left join(
select 
last_day(a.month) month,c.fusionid,a.ucid,c.dept,a.cms_defect_percentage,coalesce(round(a.cms_defect_percentage*100,2),0) "Cms Defect %"
,rank() OVER (PARTITION by a.month ORDER BY coalesce(round(a.cms_defect_percentage*100,2),0) asc,a.month ) "Cms Defect Rank"
,b."Out Of"
,case when coalesce(round(a.cms_defect_percentage*100,2),0) <0.5 then 18.5 
when coalesce(round(a.cms_defect_percentage*100,2),0) <1 then 12.5
when coalesce(round(a.cms_defect_percentage*100,2),0) <=1.5 then 6.25
else 0
end as
"Cms Defect Score"
from asit_cms_defect a
join(
select month,fusionid,ucid,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.ucid=c.ucid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)g on last_day(a.month)=g.month and a.fusionid=g.fusionid
left join(
select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)h on last_day(a.month)=h.monthn and a.dept=h.dept
left join CR_SC_AGNTS_TARGET i on last_day(a.month)=i.month and a.dept=i.dept
where --a.month>=last_day(sysdate)and
 a.dept in ('CCC-R','CCC-R SPANISH','FLEX')
and a.location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and a.designation in ('Agent')
and a.final_status='ACTIVE'
and a.team_leader not in (select name from not_teamleader)
)a)b
join(
select month,fusionid,ucid,name,TL_FUSIONID,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on b.month=c.month and b.TL_FUSIONID=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)d on b.month=d.monthn and c.dept=d.dept
left join (
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end defect_per 
 from asit_tl_impact
)e on b.month=e.month and b.TL_FUSIONID=e.fusionid
left join(
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end QC_per 
 from asit_tl_qc
)f on b.month=f.month and b.TL_FUSIONID=f.fusionid
left join CR_SC_TL_TARGET i on b.month=i.month and c.dept=i.dept
left join(
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
) j on to_char(b.month,'MON-YY')=j.month and b.TL_FUSIONID=j.fusionid
left join (select 
to_char(last_day(month),'MON-YY') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-YY'),dept
)k on to_char(b.month,'MON-YY')=k.monthn and c.dept=k.dept
--where  "EMPLOYEE ID" in('197233')
group by b.month,b.TL_FUSIONID,b."Team Lead"
,c.fusionid,c.ucid,c.TL_FUSIONID ,c.team_leader,c.location,c.dept,
i.cph_target,i.STAR_TARGET,i.ADHERENCE_TARGET,i.CMS_DEFECT_TARGET,i.collection_call_model_defect_target,i.call_monitoring_defect_target,i.ib_aht_target
,e.defect_per,f.QC_per,j."Inbound AHT",k."Out Of"
)a )a ) a 
join(
select month,fusionid,ucid,name,TL_FUSIONID,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Assistant Manager')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a."TL FUSION_ID"=c.fusionid
join(
select month,dept,count(fusionid) "Out Off" from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Assistant Manager')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by  month,dept
)d on a.month=d.month
left join CR_SC_AM_TARGET e on a.month=e.month and c.dept=e.dept
--where a.month>=last_day('01-JAN_24')
--where a."FUSION_ID" in ('195869')
group by a.month,a."TL FUSION_ID",a."MANAGER_NAME",c.ucid,c.name,c.team_leader,c.location,c.dept,d."Out Off"
,e.cph_target,e.ib_aht_target,e.cms_defect_target,e.call_monitoring_defect_target,e.collection_call_model_defect_target
)a ) a 
group by a."FUSION_ID"
)a 
--where a."EMPLOYEE ID" in (vfusionid6)
order by a."Global Rank"
;

else 
 open p_result for
 
 select * from (
select 
/*a."MONTH",
a."UCID",*/
a."FUSION_ID" "EMPLOYEE ID",
/*a."ASM_NAME",
a."MANAGER",
a."LOCATION",
a."DEPT",*/
rank() OVER (order by sum(a."Overall Score") desc,a."FUSION_ID") "Global Rank",
sum(a."Overall Score") "Total Points",
round(avg(a."Resolution Credits"),3) "Credit Per Hr" ,
--a."Res Credit Rank",
--a."Res Credit Points",
--a."CPH_TARGET",
round(avg(a."Inbound AHT"),3) "Inbound AHT",
--a."AHT Points",
--a."IB_AHT_TARGET",
round(avg(a."Cms Defect %"),3) "Cms Defect %",
--a."CMS Usage Points",
--a."CMS_DEFECT_TARGET",
round(avg(a."TL Call Monitoring Defect"),3) "TL Call Monitoring Defect",
--a."TL Call Monitoring Points",
--a."CALL_MONITORING_DEFECT_TARGET",
round(avg(a."Collection call Model Defect"),3)  "Collection call Model Defect" 
--a."Collection call Model Points",
--a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
--a."Out Off"*/
from(
select 
a."MONTH",
a."UCID",
a."FUSION_ID",
a."ASM_NAME",
a."MANAGER",
a."LOCATION",
a."DEPT",
rank() OVER (PARTITION by a."MONTH",a."DEPT" ORDER BY (round( coalesce(a."Res Credit Points",0) + coalesce(a."AHT Points",0) + coalesce(a."CMS Usage Points",0)+ coalesce(a."TL Call Monitoring Points",0) +
coalesce(a."Collection call Model Points",0)
,2)) desc,a."MONTH",a."DEPT" ) "Overall Rank",
(round( coalesce(a."Res Credit Points",0) + coalesce(a."AHT Points",0) + coalesce(a."CMS Usage Points",0)+ coalesce(a."TL Call Monitoring Points",0) +
coalesce(a."Collection call Model Points",0)
,2))"Overall Score",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Inbound AHT",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Off"
from (
select 
a.month,c.ucid,a."TL FUSION_ID" "FUSION_ID",c.name "ASM_NAME",c.team_leader "MANAGER",c.location,c.dept,
round(avg(a."Resolution Credits"),2) "Resolution Credits",
rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept ) "Res Credit Rank",
case when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept ) =1 
then 7.5
when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )=2
then 5
else 2.5 end as "Res Credit Points",
/*case when round(avg(a."Resolution Credits"),2) < 2 then 0 else
(case when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )
<=round(d."Out Off"*0.15,0) then 7.5
when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )
<=round(d."Out Off"*0.6,0) then 5 
when rank() OVER (PARTITION by a.month,c.dept ORDER BY round(avg(a."Resolution Credits"),3) desc,a.month,c.dept )
<=round(d."Out Off"*0.85,0) then 2.5 
else 0 end )
end as  "Res Credit Points",*/
e.cph_target,
round(avg(a."Inbound AHT"),2) "Inbound AHT",

case when round(avg(a."Inbound AHT"),2) > 660 then 0
 when round(avg(a."Inbound AHT"),2) >=660 then 5-(5*0.80)
when round(avg(a."Inbound AHT"),2) >=630 then 5-(5*0.60)
when round(avg(a."Inbound AHT"),2) >=600 then 5-(5*0.40)
else 5-(5*0.20) end as "AHT Points",
e.ib_aht_target,
round(avg(a."Cms Defect %"),2) "Cms Defect %",
case when round(avg(a."Cms Defect %"),2) <0.5 then 18.75
when round(avg(a."Cms Defect %"),2) < 1.0 then 12.5
when round(avg(a."Cms Defect %"),2) <1.5 then 6.25
else 0
end as "CMS Usage Points",

e.cms_defect_target,
round(avg(a."TL Call Monitoring Defect"),2) "TL Call Monitoring Defect",
case when round(avg(a."TL Call Monitoring Defect"),2) =0 then 3.75
 when round(avg(a."TL Call Monitoring Defect"),2) <= 25 then 2.5 
  when round(avg(a."TL Call Monitoring Defect"),2) <=75  then 1.25
else 0
end as "TL Call Monitoring Points",
e.call_monitoring_defect_target,
round(avg(a."Collection call Model Defect"),2) "Collection call Model Defect",
case when round(avg(a."Collection call Model Defect"),2) < 1.5 then 7.5
when round(avg(a."Collection call Model Defect"),2) < 2.5 then 5
when round(avg(a."Collection call Model Defect"),2) < 3.5 then 2.5
else 0
end "Collection call Model Points",
e.collection_call_model_defect_target,
d."Out Off"
from (
select 
a."MONTH",
a."FUSION_ID",
a."UCID",
a."SUPV_NAME",a."TL FUSION_ID",
a."MANAGER_NAME",
a."LOCATION",
a."DEPT",
a."Overall Score",
a."Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from(
select 
a."MONTH",
a."FUSION_ID",
a."UCID",
a."NAME" "SUPV_NAME",a."TL FUSION_ID",
a."TEAM_LEADER" "MANAGER_NAME",
a."LOCATION",
a."DEPT",
round((a."Res Credit Points"+a."Stella Star Points"+a."Adherence Points"+a."AHT Points"+a."CMS Usage Points"
+a."TL Call Monitoring Points"+a."Collection call Model Points"),2)  "Overall Score",
rank() OVER (PARTITION by month ORDER BY round((a."Res Credit Points"+a."Stella Star Points"+a."Adherence Points"+a."AHT Points"+a."CMS Usage Points"
+a."TL Call Monitoring Points"+a."Collection call Model Points"),2) desc,month ) "Overall Rank",
a."Resolution Credits",
a."Res Credit Rank",
a."Res Credit Points",
a."CPH_TARGET",
a."Stella Star Rating",
a."Stella Star Rank",
a."Stella Star Points",
a."STAR_TARGET",
a."Schedule Adherence",
a."Adherence Rank",
a."Adherence Points",
a."ADHERENCE_TARGET",
a."Inbound AHT",
a."AHT Rank",
a."AHT Points",
a."IB_AHT_TARGET",
a."Cms Defect %",
a."Cms Defect Rank",
a."CMS Usage Points",
a."CMS_DEFECT_TARGET",
a."TL Call Monitoring Defect",
a."TL Call Monitoring Points",
a."CALL_MONITORING_DEFECT_TARGET",
a."Collection call Model Defect",
a."Collection call Model Points",
a."COLLECTION_CALL_MODEL_DEFECT_TARGET",
a."Out Of"
from (
select 
--"EMPLOYEE ID"--,name,"Team Lead",location,dept
b.month,b.TL_FUSIONID "FUSION_ID",
c.ucid
,b."Team Lead" NAME,c.TL_FUSIONID "TL FUSION_ID", c.team_leader,c.location,c.dept
,round(avg(b."Credit Per Hr"),3) "Resolution Credits"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept ) "Res Credit Rank"
,case when round(avg(b."Credit Per Hr"),3) >2.000 then 
(case when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.15,0) then 11.25 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.6,0) then 7.5 
when rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Credit Per Hr"),3) desc,b.month,c.dept )
<=round(k."Out Of"*0.85,0) then 3.75 
else 0 end )
else 0
end as "Res Credit Points"
,i.cph_target
--,round(avg(b."Quality Score"),2) "Quality Score"
--,i.QUALITY_TARGET
,round(avg(b."Stella Star Rating"),2) "Stella Star Rating"
,rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Stella Star Rating"),2) desc,b.month,c.dept ) "Stella Star Rank"
, case when round(avg(b."Stella Star Rating"),2) >4.6 then  5-(5*0.20)
when round(avg(b."Stella Star Rating"),2) >=4.5 then  5-(5*0.40)
when round(avg(b."Stella Star Rating"),2) >=4.4 then  5-(5*0.60)
when round(avg(b."Stella Star Rating"),2) >=4.3 then  5-(5*0.80)
else 0 
end as "Stella Star Points"
,i.STAR_TARGET
,round(avg(b."Schedule Adherence"),2) "Schedule Adherence"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Schedule Adherence"),2) desc,b.month,c.dept ) "Adherence Rank"
, case when round(avg(b."Schedule Adherence"),3)>92.50 then 5-(5*0.20)
when round(avg(b."Schedule Adherence"),3)>=90.00 then 5-(5*0.40)
when round(avg(b."Schedule Adherence"),3)>=87.50 then 5-(5*0.60)
when round(avg(b."Schedule Adherence"),3)>=85.00 then 5-(5*0.80)
else 0 end as "Adherence Points"
,i.ADHERENCE_TARGET
,round(avg(b."Inbound AHT"),2) "Inbound AHT"
--,coalesce (j."Inbound AHT",0) "Inbound AHT"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Inbound AHT"),2) desc,b.month,c.dept ) "AHT Rank"
,case when round(avg(b."Inbound AHT"),2)>660 then 0
 when round(avg(b."Inbound AHT"),2) >=660 then 5-(5*0.80)
when round(avg(b."Inbound AHT"),2) >=630 then 5-(5*0.60)
when round(avg(b."Inbound AHT"),2) >=600 then 5-(5*0.40)
else 5-(5*0.20) end as "AHT Points"
,i.ib_aht_target
,round(avg(b."Cms Defect %"),2) "Cms Defect %"
, rank() OVER (PARTITION by b.month,c.dept ORDER BY round(avg(b."Cms Defect %"),2) asc,b.month,c.dept ) "Cms Defect Rank"
,case when round(avg(b."Cms Defect %"),2) <0.5 then 18.75
when round(avg(b."Cms Defect %"),2) < 1.0 then 12.5
when round(avg(b."Cms Defect %"),2) <1.5 then 6.25
else 0
end as "CMS Usage Points"
,i.CMS_DEFECT_TARGET
,f.qc_per "TL Call Monitoring Defect"
,case when f.qc_per = 0 then  7.5
when f.qc_per <= 25 then  5
when f.qc_per <= 75 then  2.5
else 0
end as  "TL Call Monitoring Points"
,i.call_monitoring_defect_target
,e.defect_per "Collection call Model Defect"
,case when e.defect_per < 1.5 then 7.5
when e.defect_per < 2.5 then 5
when e.defect_per < 3.5 then 2.5
else 0
end as "Collection call Model Points"
,i.collection_call_model_defect_target
,k."Out Of"
from
(
select 
a.month  ,a.ucid,a."EMPLOYEE ID",a.name,a.TL_FUSIONID,a."Team Lead",a.location,a.dept
,rank() OVER (PARTITION by a.month,a.dept ORDER BY
(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") desc,a.dept,a.month ) "Global Rank"
,(a."Credits Score"+coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0)
+coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0)+a."Adherence Score"+a."AHT Score"
+a."Cms Defect Score") "Total Points"
,coalesce(a."Credit Per Hr",0) "Credit Per Hr" ,a."Credit Rank",a."Credits Score",a.CPH_TARGET
, coalesce (a."Quality Score",0)  "Quality Score"
,case when a."Quality Rank" is null then 1 else a."Quality Rank" end as "Quality Rank"
,coalesce(case when a."Quality_Score"is null then 3.75 else a."Quality_Score" end,0) as "Quality_Score",a.QUALITY_TARGET
,coalesce(a."Stella Star Rating",0) "Stella Star Rating"
,case when a."Stella Star Rank" is null then 1 else a."Stella Star Rank" end as "Stella Star Rank"
,coalesce(case when a."Stella Star Score" is null then 4 else a."Stella Star Score" end,0) as "Stella Star Score",a.STAR_TARGET
,coalesce(a."Schedule Adherence",0) "Schedule Adherence",a."Adherence Rank",a."Adherence Score",a.ADHERENCE_TARGET
,coalesce(a."Inbound AHT",0) "Inbound AHT",a."AHT Rank",a."AHT Score",a.IB_AHT_TARGET
,coalesce(a."Cms Defect %",0) "Cms Defect %" ,a."Cms Defect Rank",a."Cms Defect Score",a.CMS_DEFECT_TARGET
,a."Out Of"
from
(
select 
last_day(a.month) month,
a.ucid,
a.fusionid "EMPLOYEE ID",
a.name,
a.TL_FUSIONID,
a.team_leader "Team Lead",
a.location,
a.dept
--,rank() OVER (PARTITION by last_day(a.month),a.dept ORDER BY (coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0)) desc,a.dept,last_day(a.month) ) "Global Rank"
--,(coalesce(b."Credits Score",0)+coalesce(c."Quality_Score",0)+coalesce(d."Stella Star Score",0)+coalesce(e."Adherence Score",0)+coalesce(f."AHT Score",0)+coalesce(g."Cms Defect Score",0))  "Total Points"
,b."Credit Per Hr",b."Credit Rank",b."Credits Score",
--b.CPH_TARGET
i.CPH_TARGET
,c."Quality Score",c."Quality Rank",c."Quality_Score"
,i.QUALITY_TARGET
,d."Stella Star Rating",d."Stella Star Rank",d."Stella Star Score"
,i.STAR_TARGET
,e."Schedule Adherence",e."Adherence Rank",e."Adherence Score"
,i.ADHERENCE_TARGET
,f."Inbound AHT",f."AHT Rank",f."AHT Score"
,i.IB_AHT_TARGET
,g."Cms Defect %",g."Cms Defect Rank",g."Cms Defect Score"
,i.CMS_DEFECT_TARGET
,h."Out Of"
from asit_roster_table a
left join(
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
--,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
,"CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
,e."CPH_TARGET"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
left join(
select month,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95","CPH_TARGET"
from (
select month,fusionid,ucid,emp_name,dept,"Credit Per Hr","Credit Rank","Credits Score","Out Of","Out of 95"
,case when cast("Out of 95" as number)=cast("Credit Rank" as number) then "Credit Per Hr" end as "CPH_TARGET"
from (
select last_day(a.rpt_month) month,c.fusionid,a.ucid,a.emp_name,c.dept,cast(coalesce(max(a.credits_per_hour),0) as decimal(10,3)) "Credit Per Hr"
,rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) ) "Credit Rank"
,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.15) then 18.75 
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.6) then 12.50
when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(max(a.credits_per_hour),0) desc,c.dept,last_day(a.rpt_month) )
<=round(b."Out Of"*0.95) then 6.25 else 0
end as "Credits Score"
--,d.cph_target
--,case when rank() OVER (PARTITION by last_day(a.rpt_month),c.dept ORDER BY coalesce(round(max(a.credits_per_hour),1),0) desc,c.dept,last_day(a.rpt_month) )=round(b."Out Of"*0.95) then coalesce(round(max(a.credits_per_hour),1),0) else '' end as   "Target"
,b."Out Of", round(b."Out Of"*0.95) "Out of 95"
from asit_res_credits a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.rpt_month)=last_day(c.month) and a.ucid=c.ucid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.rpt_month)=b.monthn and c.dept=b.dept
left join cr_sc_agnts_target d on last_day(a.rpt_month)=last_day(d.month) and c.dept=d.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of"
)a )b
where "CPH_TARGET" is not null)e on last_day(a.rpt_month)=last_day(e.month) and c.dept=e.dept
group by last_day(a.rpt_month),c.fusionid,a.ucid,a.emp_name,c.dept,d.cph_target,b."Out Of",e."CPH_TARGET"
)a
) b on last_day(a.month)=last_day(b.month) and a.fusionid=b.fusionid
left join(
select last_day(roster_month) month,
a.fusion_id,c.ucid,a.employee_name,c.dept
,coalesce(round(avg(score),2),0) "Quality Score"
,rank() OVER (PARTITION by last_day(roster_month),c.dept ORDER BY coalesce(round(avg(score),2),0) desc,c.dept,last_day(roster_month) )  "Quality Rank"
,b."Out Of"
,case 
when coalesce(round(avg(score),2),0) >=97.50  then 3.75 
when coalesce(round(avg(score),2),0) >=95.20  then 2.5
when coalesce(round(avg(score),2),0) >=90  then 1.25 
else 0
end as
"Quality_Score"
from asit_quality a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on last_day(a.roster_month)=c.month and a.fusion_id=c.fusionid
join(select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on last_day(a.roster_month)=b.monthn and b.dept=c.dept
--where a.roster_month=last_day('31-JAN-24') 
--and a.ucid in (select distinct ucid from asit_roster_table where fusionid='105554' ) 
group by last_day(roster_month),a.fusion_id,c.ucid,a.employee_name,c.dept,b."Out Of"

)c on last_day(a.month)=last_day(c.month) and a.fusionid=c.fusion_id
left join(
select 
last_day(a.month) month,a.employee_custom_id,c.dept
--,a.team_leader
,coalesce(round(avg(star_rating),2),0) "Stella Star Rating"
,rank() OVER (PARTITION by last_day(a.month),c.dept  ORDER BY coalesce(round(avg(star_rating),2),0) desc,c.dept ,last_day(a.month) ) "Stella Star Rank"
,b."Out Of"
,case when coalesce(round(avg(star_rating),2),0) >= 4.6 then 4.00
when coalesce(round(avg(star_rating),2),0) >= 4.5 then 3.00 
when coalesce(round(avg(star_rating),2),0) >= 4.4 then 2.00
when coalesce(round(avg(star_rating),2),0) >= 4.3 then 1.00
else 0
end as "Stella Star Score"
from asit_star_rating a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.employee_custom_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
--where  a.month=last_day(a.month)
--and employee_custom_id in ('196400') 
group by last_day(a.month),c.dept,a.employee_custom_id,b."Out Of"
)d on last_day(a.month)=last_day(d.month) and a.fusionid=d.employee_custom_id
left join (
select 
last_day(a.month) month,a.fusion_id,c.dept 
,coalesce(round(adherence_percentage*100,2),0) "Schedule Adherence"
,rank() OVER (PARTITION by last_day(a.month),c.dept ORDER BY coalesce(round(adherence_percentage*100,2),0) desc,c.dept ,last_day(a.month) ) "Adherence Rank"
,b."Out Of"
,case when coalesce(round(adherence_percentage*100,2),0) >=95 then 4.00 
when coalesce(round(adherence_percentage*100,2),0) >=92.5 then 3.00
when coalesce(round(adherence_percentage*100,2),0) >=90 then 2.00 
when coalesce(round(adherence_percentage*100,2),0) >=87.5 then 1.00
else 0
end as
"Adherence Score"
from asit_telephony a
join(
select month,fusionid,ucid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.fusion_id=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)e on last_day(a.month)=last_day(e.month) and a.fusionid=e.fusion_id
left join (
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
)f on to_char(last_day(a.month),'MON-YY')=f.month and a.fusionid=f.fusionid
left join(
select 
last_day(a.month) month,c.fusionid,a.ucid,c.dept,a.cms_defect_percentage,coalesce(round(a.cms_defect_percentage*100,2),0) "Cms Defect %"
,rank() OVER (PARTITION by a.month ORDER BY coalesce(round(a.cms_defect_percentage*100,2),0) asc,a.month ) "Cms Defect Rank"
,b."Out Of"
,case when coalesce(round(a.cms_defect_percentage*100,2),0) <0.5 then 18.5 
when coalesce(round(a.cms_defect_percentage*100,2),0) <1 then 12.5
when coalesce(round(a.cms_defect_percentage*100,2),0) <=1.5 then 6.25
else 0
end as
"Cms Defect Score"
from asit_cms_defect a
join(
select month,fusionid,ucid,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a.ucid=c.ucid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)b on a.month=b.monthn and c.dept=b.dept
)g on last_day(a.month)=g.month and a.fusionid=g.fusionid
left join(
select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Agent')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)h on last_day(a.month)=h.monthn and a.dept=h.dept
left join CR_SC_AGNTS_TARGET i on last_day(a.month)=i.month and a.dept=i.dept
where --a.month>=last_day(sysdate)and
 a.dept in ('CCC-R','CCC-R SPANISH','FLEX')
and a.location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and a.designation in ('Agent')
and a.final_status='ACTIVE'
and a.team_leader not in (select name from not_teamleader)
)a)b
join(
select month,fusionid,ucid,name,TL_FUSIONID,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on b.month=c.month and b.TL_FUSIONID=c.fusionid
join (select last_day(month) monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by month,dept
)d on b.month=d.monthn and c.dept=d.dept
left join (
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end defect_per 
 from asit_tl_impact
)e on b.month=e.month and b.TL_FUSIONID=e.fusionid
left join(
select MONTH,FUSIONID,UCID,NAME,ASST_MNGR_NAME,MNGR_NAME,LOCATION,DEPT,OPPORTUNITIES,DEFECT
,case when defect=0 then 0 else round((DEFECT/OPPORTUNITIES)*100,3) end QC_per 
 from asit_tl_qc
)f on b.month=f.month and b.TL_FUSIONID=f.fusionid
left join CR_SC_TL_TARGET i on b.month=i.month and c.dept=i.dept
left join(
select
a.month,c.fusionid,a.logon_id,a.emp_name,c.dept,coalesce(a.AHT,0) "Inbound AHT",
rank() OVER (PARTITION by a.month,c.dept ORDER BY coalesce(a.AHT,0) asc,c.dept,a.month ) "AHT Rank"
,b."Out Of"
,case when coalesce(a.AHT,0)<=600 then 7.5
when coalesce(a.AHT,0)<=630 then 5
when coalesce(a.AHT,0)<=660 then 2.5
else 0
end as
"AHT Score"
from (
select to_char(a.month,'MON-yy') month
--,c.fusionid
,a.logon_id,a.emp_name,sum(a.calls_handled),sum(a.handle_time),
round(sum(a.handle_time)/sum(a.calls_handled),2) AHT
,a.direction 
from asit_aht a
where
a.direction='Inbound'
--and a.emp_name in(select name from asit_roster_table where fusionid='193222')
group by to_char(a.month,'MON-yy'),a.logon_id,a.emp_name,a.direction 
) a 
join(
select to_char(month,'MON-yy') month,fusionid,ucid,ntid,livevox_id,name,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and upper(a.logon_id)=upper(c.livevox_id)  --and a.emp_name =c.name 
left join (select 
to_char(last_day(month),'MON-yy') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-yy'),dept
)b on a.month=b.monthn and c.dept=b.dept
) j on to_char(b.month,'MON-YY')=j.month and b.TL_FUSIONID=j.fusionid
left join (select 
to_char(last_day(month),'MON-YY') monthn,dept,count(*) "Out Of"
from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Team Lead')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by to_char(last_day(month),'MON-YY'),dept
)k on to_char(b.month,'MON-YY')=k.monthn and c.dept=k.dept
--where  "EMPLOYEE ID" in('197233')
group by b.month,b.TL_FUSIONID,b."Team Lead"
,c.fusionid,c.ucid,c.TL_FUSIONID ,c.team_leader,c.location,c.dept,
i.cph_target,i.STAR_TARGET,i.ADHERENCE_TARGET,i.CMS_DEFECT_TARGET,i.collection_call_model_defect_target,i.call_monitoring_defect_target,i.ib_aht_target
,e.defect_per,f.QC_per,j."Inbound AHT",k."Out Of"
)a )a ) a 
join(
select month,fusionid,ucid,name,TL_FUSIONID,team_leader,location,dept,designation from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Assistant Manager')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
)c on a.month=c.month and a."TL FUSION_ID"=c.fusionid
join(
select month,dept,count(fusionid) "Out Off" from asit_roster_table
where month=last_day(month)
and dept in ('CCC-R','CCC-R SPANISH','FLEX')
and location in ('MUM','BAN','MTL','PMC','RC','STX','WPB')
and designation in ('Assistant Manager')
and final_status='ACTIVE'
and team_leader not in (select name from not_teamleader)
group by  month,dept
)d on a.month=d.month
left join CR_SC_AM_TARGET e on a.month=e.month and c.dept=e.dept
--where a.month>=last_day('01-JAN_24')
--where a."FUSION_ID" in ('195869')
group by a.month,a."TL FUSION_ID",a."MANAGER_NAME",c.ucid,c.name,c.team_leader,c.location,c.dept,d."Out Off"
,e.cph_target,e.ib_aht_target,e.cms_defect_target,e.call_monitoring_defect_target,e.collection_call_model_defect_target
)a ) a 
group by a."FUSION_ID"
)a 
where a."EMPLOYEE ID" in (vfusionid6)
order by a."Global Rank"
;
 end if;
 
END CR_SC_YTD_AM; 
 
 
 
  
END SCORECARD;