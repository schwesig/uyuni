DROP VIEW rhnServerOverview;

create or replace view
rhnServerOverview
(
    org_id,
    server_id,
    server_name,
    modified,
    server_admins,
    group_count,
    channel_id,
    channel_labels,
    history_count,
    security_errata,
    bug_errata,
    enhancement_errata,
    outdated_packages,
	config_files_with_differences,
    last_checkin_days_ago,
    last_checkin,
    pending_updates,
    os,
    release,
    server_arch_name,
    locked,
    is_proxy,
    is_mgr_server
)
as
select
    s.org_id, s.id, s.name, s.modified,
    ( select count(user_id) from rhnUserServerPerms ap
      where server_id = s.id ),
    ( select count(server_group_id) from rhnVisibleServerGroupMembers
      where server_id = s.id ),
    ( select C.id
        from rhnChannel C,
	     rhnServerChannel SC
       where SC.server_id = S.id
         and SC.channel_id = C.id
	 and C.parent_channel IS NULL),
    coalesce(( select C.name
        from rhnChannel C,
	     rhnServerChannel SC
       where SC.server_id = S.id
         and SC.channel_id = C.id
	 and C.parent_channel IS NULL), '(none)'),
    ( select count(id) from rhnServerHistory
      where
            server_id = S.id),
    ( select count(*) from rhnServerErrataTypeView setv
      where
            setv.server_id = s.id
        and setv.errata_type = 'Security Advisory'),
    ( select count(*) from rhnServerErrataTypeView setv
      where
            setv.server_id = s.id
        and setv.errata_type = 'Bug Fix Advisory'),
    ( select count(*) from rhnServerErrataTypeView setv
      where
            setv.server_id = s.id
        and setv.errata_type = 'Product Enhancement Advisory'),
    ( select count(distinct p.name_id) from rhnPackage p, rhnServerNeededCache snc
      where
             snc.server_id = S.id
	 and p.id = snc.package_id
	 ),
    ( select count(*)
        from rhnActionConfigRevision ACR
             INNER JOIN rhnActionConfigRevisionResult ACRR on ACR.id = ACRR.action_config_revision_id
       where ACR.server_id = S.id
         and ACR.action_id = (
              select MAX(rA.id)
                from rhnAction rA
                     INNER JOIN rhnServerAction rSA on rSA.action_id = rA.id
                     INNER JOIN rhnActionStatus rAS on rAS.id = rSA.status
                     INNER JOIN rhnActionType rAT on rAT.id = rA.action_type
               where rSA.server_id = S.id
                 and rAS.name in ('Completed', 'Failed')
                 and rAT.label = 'configfiles.diff'
         )
         and ACR.failure_id is null
         and ACRR.result is not null
        ),
    ( select date_diff_in_days(checkin, current_timestamp) from rhnServerInfo where server_id = S.id ),
    ( select TO_CHAR(checkin, 'YYYY-MM-DD HH24:MI:SS') from rhnServerInfo where server_id = S.id ),
    ( select count(1)
        from rhnServerAction
       where server_id = S.id
         and status in (0, 1)),
    os,
    release,
    ( select name from rhnServerArch where id = s.server_arch_id),
    coalesce((select 1 from rhnServerLock SL WHERE SL.server_id = S.id), 0),
    coalesce((select TRUE from rhnProxyInfo pxy where pxy.server_id = S.id), FALSE),
    coalesce((select TRUE from suseMgrServerInfo mgrs where mgrs.server_id = S.id), FALSE)
from
    rhnServer S
;

