select(dbuser:string, db:string, participant_id:string, data_id:string)
insert(dbuser:string, db:string, participant_id:string, data_id:string)
update(dbuser:string, db:string, participant_id:string, data_id:string)
delete(dbuser:string, db:string, participant_id:string, data_id:string)
script_start(script:string)
script_end(script:string)
script_svn(file:string, status:string, url:string, rev1:int, rev2:int)
script_md5(file:string, md5:string)
commit(url:string, rev:int)